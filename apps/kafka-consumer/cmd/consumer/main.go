package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/IBM/sarama"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// ── Metrics ───────────────────────────────────────────────────────────────────
var (
	messagesProcessed = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "kafka_messages_processed_total",
		Help: "Total Kafka messages processed",
	}, []string{"topic", "status"})

	processingDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "kafka_message_processing_seconds",
		Help:    "Kafka message processing duration",
		Buckets: prometheus.DefBuckets,
	}, []string{"topic"})

	dlqMessages = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "kafka_dlq_messages_total",
		Help: "Messages sent to dead-letter queue",
	}, []string{"topic", "reason"})
)

// ── Config ────────────────────────────────────────────────────────────────────
type Config struct {
	Brokers       []string
	Topic         string
	ConsumerGroup string
	DLQTopic      string
	MaxRetries    int
}

func configFromEnv() Config {
	brokers := os.Getenv("KAFKA_BROKERS")
	if brokers == "" {
		brokers = "localhost:9092"
	}
	topic := os.Getenv("KAFKA_TOPIC")
	if topic == "" {
		topic = "platform-events"
	}
	group := os.Getenv("KAFKA_CONSUMER_GROUP")
	if group == "" {
		group = "platform-consumer"
	}
	return Config{
		Brokers:       strings.Split(brokers, ","),
		Topic:         topic,
		ConsumerGroup: group,
		DLQTopic:      topic + ".dlq",
		MaxRetries:    3,
	}
}

// ── Message ────────────────────────────────────────────────────────────────────
type Event struct {
	ID        string          `json:"id"`
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
	Timestamp time.Time       `json:"timestamp"`
}

// ── Consumer handler ──────────────────────────────────────────────────────────
type Handler struct {
	producer sarama.SyncProducer
	cfg      Config
}

func (h *Handler) Setup(sarama.ConsumerGroupSession) error   { return nil }
func (h *Handler) Cleanup(sarama.ConsumerGroupSession) error { return nil }

func (h *Handler) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for msg := range claim.Messages() {
		start := time.Now()
		err := h.process(msg)
		dur := time.Since(start).Seconds()
		processingDuration.WithLabelValues(msg.Topic).Observe(dur)

		if err != nil {
			slog.Error("processing failed — sending to DLQ", "topic", msg.Topic, "offset", msg.Offset, "err", err)
			h.sendDLQ(msg, err.Error())
			messagesProcessed.WithLabelValues(msg.Topic, "dlq").Inc()
		} else {
			messagesProcessed.WithLabelValues(msg.Topic, "ok").Inc()
			session.MarkMessage(msg, "")
		}
	}
	return nil
}

func (h *Handler) process(msg *sarama.ConsumerMessage) error {
	var event Event
	if err := json.Unmarshal(msg.Value, &event); err != nil {
		return err
	}
	slog.Info("processing event", "id", event.ID, "type", event.Type, "topic", msg.Topic)
	// TODO: dispatch by event.Type to domain handlers
	return nil
}

func (h *Handler) sendDLQ(msg *sarama.ConsumerMessage, reason string) {
	if h.producer == nil {
		return
	}
	_, _, err := h.producer.SendMessage(&sarama.ProducerMessage{
		Topic: h.cfg.DLQTopic,
		Key:   sarama.ByteEncoder(msg.Key),
		Value: sarama.ByteEncoder(msg.Value),
		Headers: []sarama.RecordHeader{
			{Key: []byte("dlq-reason"), Value: []byte(reason)},
			{Key: []byte("original-topic"), Value: []byte(msg.Topic)},
		},
	})
	if err != nil {
		slog.Error("failed to send DLQ message", "err", err)
	}
	dlqMessages.WithLabelValues(h.cfg.DLQTopic, reason).Inc()
}

// ── Main ──────────────────────────────────────────────────────────────────────
func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	cfg := configFromEnv()

	// Health + metrics server
	go func() {
		mux := http.NewServeMux()
		mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
		})
		mux.Handle("/metrics", promhttp.Handler())
		slog.Info("health server started", "port", "8080")
		http.ListenAndServe(":8080", mux)
	}()

	saramaCfg := sarama.NewConfig()
	saramaCfg.Version = sarama.V3_5_0_0
	saramaCfg.Consumer.Group.Rebalance.GroupStrategies = []sarama.BalanceStrategy{sarama.NewBalanceStrategyRoundRobin()}
	saramaCfg.Consumer.Offsets.Initial = sarama.OffsetNewest
	saramaCfg.Consumer.Return.Errors = true

	// DLQ producer
	producer, err := sarama.NewSyncProducer(cfg.Brokers, nil)
	if err != nil {
		slog.Warn("could not create DLQ producer — continuing without DLQ", "err", err)
	}

	cg, err := sarama.NewConsumerGroup(cfg.Brokers, cfg.ConsumerGroup, saramaCfg)
	if err != nil {
		slog.Error("failed to create consumer group", "err", err)
		os.Exit(1)
	}
	defer cg.Close()

	handler := &Handler{producer: producer, cfg: cfg}
	ctx, cancel := context.WithCancel(context.Background())

	go func() {
		for err := range cg.Errors() {
			slog.Error("consumer group error", "err", err)
		}
	}()

	go func() {
		for {
			if err := cg.Consume(ctx, []string{cfg.Topic}, handler); err != nil {
				slog.Error("consume error", "err", err)
				time.Sleep(5 * time.Second)
			}
			if ctx.Err() != nil {
				return
			}
		}
	}()

	slog.Info("kafka consumer started", "brokers", cfg.Brokers, "topic", cfg.Topic, "group", cfg.ConsumerGroup)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)
	<-quit
	cancel()
	slog.Info("consumer stopped")
}
