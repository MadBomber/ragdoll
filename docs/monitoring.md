# Monitoring & Analytics

Ragdoll provides comprehensive monitoring and analytics capabilities built directly into the PostgreSQL database schema. The system tracks usage patterns, performance metrics, and system health through ActiveRecord models and native PostgreSQL features.

## Usage Tracking and System Health

The monitoring system is built around PostgreSQL's native capabilities and pgvector optimization, providing real-time insights into system performance, usage patterns, and content analytics. All monitoring data is stored in the same database as your content, ensuring consistency and reducing infrastructure complexity.

## Usage Analytics

Ragdoll automatically tracks usage patterns through the embedding model's built-in analytics fields. This data drives both performance optimization and business intelligence.

### Search Analytics

Every search operation is tracked through the `usage_count` and `returned_at` fields in the embeddings table:

```ruby
# Get search frequency data
freq_data = Ragdoll::Core::Models::Embedding
  .frequently_used
  .group(:embeddable_id)
  .sum(:usage_count)

# Popular content identification
popular_embeddings = Ragdoll::Core::Models::Embedding
  .where('usage_count > ?', 10)
  .joins(:embeddable)
  .includes(embeddable: :document)
  .order(usage_count: :desc)

# Recent search patterns
recent_activity = Ragdoll::Core::Models::Embedding
  .where('returned_at > ?', 7.days.ago)
  .group_by_day(:returned_at)
  .count

# Query performance metrics
search_performance = {
  avg_results_per_query: popular_embeddings.average(:usage_count),
  total_searches: Ragdoll::Core::Models::Embedding.sum(:usage_count),
  unique_content_accessed: Ragdoll::Core::Models::Embedding.where('usage_count > 0').count
}
```

### Embedding Analytics

Track embedding model performance and usage patterns:

```ruby
# Embedding usage by model type
usage_by_model = Ragdoll::Core::Models::Embedding
  .joins(:embeddable)
  .group('ragdoll_contents.embedding_model')
  .count

# Vector quality metrics through similarity distribution
similarity_stats = {
  high_quality: Ragdoll::Core::Models::Embedding.where('usage_count > 5').count,
  medium_quality: Ragdoll::Core::Models::Embedding.where('usage_count BETWEEN 1 AND 5').count,
  unused: Ragdoll::Core::Models::Embedding.where(usage_count: 0).count
}

# Cache effectiveness (usage-based ranking)
cache_metrics = {
  frequently_accessed: Ragdoll::Core::Models::Embedding
    .where('returned_at > ?', 24.hours.ago)
    .average(:usage_count),
  recency_distribution: Ragdoll::Core::Models::Embedding
    .where('returned_at IS NOT NULL')
    .group_by_day(:returned_at, last: 30)
    .count
}
```

### Document Analytics

Monitor document processing and access patterns:

```ruby
# Document processing success rates
processing_stats = Ragdoll::Core::Models::Document.group(:status).count
# => {"processed"=>45, "pending"=>3, "error"=>2}

# Content type distribution
content_distribution = Ragdoll::Core::Models::Document.group(:document_type).count
# => {"text"=>25, "pdf"=>15, "image"=>8, "audio"=>2}

# Comprehensive document statistics
doc_stats = Ragdoll::Core::Models::Document.stats
# Returns detailed hash with processing metrics, content counts, etc.

# Storage utilization by content type
storage_metrics = {
  text_content_count: Ragdoll::Core::Models::TextContent.count,
  image_content_count: Ragdoll::Core::Models::ImageContent.count,
  audio_content_count: Ragdoll::Core::Models::AudioContent.count,
  total_embeddings: Ragdoll::Core::Models::Embedding.count,
  avg_embeddings_per_document: Ragdoll::Core::Models::Document
    .joins(:text_embeddings, :image_embeddings, :audio_embeddings)
    .average('COUNT(*)')
}
```

## System Health Monitoring

Monitor system health through PostgreSQL native features and ActiveRecord connection management.

### Database Health

Utilize PostgreSQL's built-in statistics and monitoring capabilities:

```ruby
# Connection pool status
pool_status = ActiveRecord::Base.connection_pool.stat
# => {size: 20, checked_out: 3, checked_in: 17, ...}

# Query performance metrics using PostgreSQL pg_stat_statements
ActiveRecord::Base.connection.execute("
  SELECT query, calls, total_time, mean_time, rows
  FROM pg_stat_statements
  WHERE query LIKE '%ragdoll%'
  ORDER BY mean_time DESC;
")

# Index usage statistics
index_stats = ActiveRecord::Base.connection.execute("
  SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch
  FROM pg_stat_user_indexes
  WHERE schemaname = 'public'
  AND tablename LIKE 'ragdoll_%';
")

# Storage utilization
table_sizes = ActiveRecord::Base.connection.execute("
  SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size('ragdoll_'||tablename)) as size
  FROM pg_tables
  WHERE tablename LIKE 'ragdoll_%';
")
```

### Background Job Health

Monitor ActiveJob performance through document status tracking:

```ruby
# Job success/failure tracking through document status
job_health = {
  successful_processing: Ragdoll::Core::Models::Document.where(status: 'processed').count,
  failed_processing: Ragdoll::Core::Models::Document.where(status: 'error').count,
  pending_jobs: Ragdoll::Core::Models::Document.where(status: 'pending').count,
  currently_processing: Ragdoll::Core::Models::Document.where(status: 'processing').count
}

# Processing time analysis
recent_docs = Ragdoll::Core::Models::Document
  .where('created_at > ?', 24.hours.ago)
  .where(status: 'processed')

processing_times = recent_docs.map do |doc|
  (doc.updated_at - doc.created_at).to_i
end

performance_metrics = {
  avg_processing_time: processing_times.sum / processing_times.length,
  median_processing_time: processing_times.sort[processing_times.length / 2],
  max_processing_time: processing_times.max,
  success_rate: (job_health[:successful_processing].to_f /
                (job_health[:successful_processing] + job_health[:failed_processing])) * 100
}
```

### Memory and CPU Monitoring

Integrate with system monitoring tools and PostgreSQL process information:

```ruby
# PostgreSQL process monitoring
process_info = ActiveRecord::Base.connection.execute("
  SELECT
    pid,
    usename,
    application_name,
    state,
    query_start,
    query
  FROM pg_stat_activity
  WHERE application_name LIKE '%ragdoll%';
")

# Memory usage through Ruby process monitoring
memory_usage = {
  process_memory: `ps -o rss= -p #{Process.pid}`.to_i * 1024, # bytes
  gc_stats: GC.stat,
  object_space: ObjectSpace.count_objects
}

# Connection monitoring
connection_health = {
  active_connections: ActiveRecord::Base.connection_pool.connections.size,
  checked_out: ActiveRecord::Base.connection_pool.stat[:checked_out],
  available: ActiveRecord::Base.connection_pool.stat[:size] -
             ActiveRecord::Base.connection_pool.stat[:checked_out]
}
```

## Metrics Collection

Ragdoll provides built-in metrics collection through ActiveRecord queries and PostgreSQL native features.

### Built-in Metrics Endpoints

Create monitoring endpoints using the comprehensive statistics methods:

```ruby
# Complete system metrics collection
def collect_system_metrics
  {
    timestamp: Time.current.iso8601,
    documents: Ragdoll::Core::Models::Document.stats,
    embeddings: {
      total: Ragdoll::Core::Models::Embedding.count,
      by_type: {
        text: Ragdoll::Core::Models::Embedding.text_embeddings.count,
        image: Ragdoll::Core::Models::Embedding.image_embeddings.count,
        audio: Ragdoll::Core::Models::Embedding.audio_embeddings.count
      },
      usage_stats: {
        total_searches: Ragdoll::Core::Models::Embedding.sum(:usage_count),
        active_last_24h: Ragdoll::Core::Models::Embedding
          .where('returned_at > ?', 24.hours.ago).count,
        never_used: Ragdoll::Core::Models::Embedding.where(usage_count: 0).count
      }
    },
    performance: {
      avg_similarity_threshold: Ragdoll.config.search[:similarity_threshold],
      max_results_configured: Ragdoll.config.search[:max_results],
      analytics_enabled: Ragdoll.config.search[:enable_analytics]
    }
  }
end

# Usage pattern metrics
def collect_usage_metrics
  {
    popular_content: Ragdoll::Core::Models::Embedding
      .frequently_used
      .limit(10)
      .includes(embeddable: :document)
      .map { |e| {
        document_title: e.embeddable.document.title,
        usage_count: e.usage_count,
        last_accessed: e.returned_at
      }},
    search_patterns: {
      daily_searches: Ragdoll::Core::Models::Embedding
        .where('returned_at > ?', 30.days.ago)
        .group_by_day(:returned_at)
        .sum(:usage_count),
      content_type_preferences: Ragdoll::Core::Models::Embedding
        .joins(:embeddable)
        .group('ragdoll_contents.type')
        .sum(:usage_count)
    }
  }
end
```

### Custom Metrics Definition

Extend the monitoring system with custom business metrics:

```ruby
class CustomMetrics
  def self.document_processing_velocity
    # Documents processed per hour over last 24 hours
    Ragdoll::Core::Models::Document
      .where('updated_at > ?', 24.hours.ago)
      .where(status: 'processed')
      .group_by_hour(:updated_at)
      .count
  end

  def self.embedding_quality_distribution
    # Distribution of embedding usage as quality indicator
    {
      high_quality: Ragdoll::Core::Models::Embedding.where('usage_count >= 10').count,
      medium_quality: Ragdoll::Core::Models::Embedding.where('usage_count BETWEEN 3 AND 9').count,
      low_quality: Ragdoll::Core::Models::Embedding.where('usage_count BETWEEN 1 AND 2').count,
      unused: Ragdoll::Core::Models::Embedding.where(usage_count: 0).count
    }
  end

  def self.multi_modal_adoption
    # Track multi-modal document usage
    {
      text_only: Ragdoll::Core::Models::Document.joins(:text_contents)
        .where.not(id: Ragdoll::Core::Models::Document.joins(:image_contents).select(:id))
        .where.not(id: Ragdoll::Core::Models::Document.joins(:audio_contents).select(:id))
        .count,
      multi_modal: Ragdoll::Core::Models::Document
        .where(id: Ragdoll::Core::Models::Document.joins(:text_contents, :image_contents).select(:id))
        .or(Ragdoll::Core::Models::Document.where(id: Ragdoll::Core::Models::Document.joins(:text_contents, :audio_contents).select(:id)))
        .count
    }
  end
end
```

### Data Export Capabilities

Export metrics data for external analysis:

```ruby
# Export to JSON for external monitoring systems
def export_metrics_json(start_date: 30.days.ago, end_date: Time.current)
  {
    export_info: {
      generated_at: Time.current.iso8601,
      period: { start: start_date.iso8601, end: end_date.iso8601 },
      ragdoll_version: Ragdoll::Core::VERSION
    },
    documents: {
      created: Ragdoll::Core::Models::Document
        .where(created_at: start_date..end_date)
        .group(:status, :document_type)
        .count,
      processing_times: Ragdoll::Core::Models::Document
        .where(created_at: start_date..end_date, status: 'processed')
        .pluck(:created_at, :updated_at)
        .map { |created, updated| (updated - created).to_i }
    },
    search_analytics: {
      total_searches: Ragdoll::Core::Models::Embedding
        .where(returned_at: start_date..end_date)
        .sum(:usage_count),
      unique_content_accessed: Ragdoll::Core::Models::Embedding
        .where(returned_at: start_date..end_date)
        .distinct
        .count(:embeddable_id)
    }
  }.to_json
end

# Export to CSV for spreadsheet analysis
def export_usage_csv
  require 'csv'

  CSV.generate(headers: true) do |csv|
    csv << ['Document Title', 'Document Type', 'Embedding Count', 'Total Usage', 'Last Accessed']

    Ragdoll::Core::Models::Document.includes(:contents, :text_embeddings).find_each do |doc|
      csv << [
        doc.title,
        doc.document_type,
        doc.total_embedding_count,
        doc.text_embeddings.sum(:usage_count),
        doc.text_embeddings.maximum(:returned_at)
      ]
    end
  end
end
```

### Historical Data Retention

Manage historical metrics data with PostgreSQL partitioning and cleanup:

```ruby
# Data retention policies
class MetricsRetention
  def self.cleanup_old_usage_data(retention_days: 365)
    # Clear old returned_at timestamps but keep usage_count
    old_threshold = retention_days.days.ago

    Ragdoll::Core::Models::Embedding
      .where('returned_at < ?', old_threshold)
      .update_all(returned_at: nil)
  end

  def self.archive_document_metrics(archive_after_days: 180)
    # Archive processed documents older than threshold
    archive_threshold = archive_after_days.days.ago

    old_docs = Ragdoll::Core::Models::Document
      .where('created_at < ? AND status = ?', archive_threshold, 'processed')

    # Could export to JSON before cleanup
    archive_data = old_docs.map(&:to_hash)

    # Store archive data or remove based on retention policy
    # This is application-specific implementation
  end

  def self.metrics_summary_for_period(days: 30)
    period_start = days.days.ago

    {
      period: "#{days} days",
      documents_processed: Ragdoll::Core::Models::Document
        .where('created_at > ? AND status = ?', period_start, 'processed')
        .count,
      total_searches: Ragdoll::Core::Models::Embedding
        .where('returned_at > ?', period_start)
        .sum(:usage_count),
      new_embeddings: Ragdoll::Core::Models::Embedding
        .where('created_at > ?', period_start)
        .count
    }
  end
end
```

## Performance Dashboards

Create comprehensive dashboards using the built-in metrics collection and PostgreSQL analytics capabilities.

### Real-time Performance Views

Build live monitoring dashboards with ActiveRecord queries:

```ruby
class PerformanceDashboard
  def self.realtime_stats
    {
      current_time: Time.current.iso8601,
      system_status: {
        total_documents: Ragdoll::Core::Models::Document.count,
        processing_queue: Ragdoll::Core::Models::Document.where(status: 'pending').count,
        currently_processing: Ragdoll::Core::Models::Document.where(status: 'processing').count,
        failed_jobs: Ragdoll::Core::Models::Document.where(status: 'error').count
      },
      recent_activity: {
        documents_added_today: Ragdoll::Core::Models::Document
          .where('created_at > ?', Date.current)
          .count,
        searches_last_hour: Ragdoll::Core::Models::Embedding
          .where('returned_at > ?', 1.hour.ago)
          .sum(:usage_count),
        embeddings_created_today: Ragdoll::Core::Models::Embedding
          .where('created_at > ?', Date.current)
          .count
      },
      performance_indicators: {
        avg_search_quality: Ragdoll::Core::Models::Embedding
          .where('returned_at > ?', 24.hours.ago)
          .average(:usage_count) || 0,
        content_utilization: (Ragdoll::Core::Models::Embedding.where('usage_count > 0').count.to_f /
                             Ragdoll::Core::Models::Embedding.count * 100).round(2),
        processing_success_rate: calculate_success_rate
      }
    }
  end

  def self.calculate_success_rate
    total = Ragdoll::Core::Models::Document.count
    return 0 if total == 0

    successful = Ragdoll::Core::Models::Document.where(status: 'processed').count
    (successful.to_f / total * 100).round(2)
  end
end

# Usage in a web dashboard
def dashboard_data
  {
    realtime: PerformanceDashboard.realtime_stats,
    queue_health: {
      processing_velocity: documents_per_hour,
      error_rate: error_percentage_last_24h,
      average_processing_time: avg_processing_time_minutes
    }
  }
end
```

### Historical Trend Analysis

Analyze trends over time using PostgreSQL date functions:

```ruby
class TrendAnalysis
  def self.document_processing_trends(days: 30)
    end_date = Date.current
    start_date = end_date - days.days

    {
      daily_processing: Ragdoll::Core::Models::Document
        .where(created_at: start_date..end_date)
        .where(status: 'processed')
        .group_by_day(:updated_at, range: start_date..end_date)
        .count,
      daily_failures: Ragdoll::Core::Models::Document
        .where(created_at: start_date..end_date)
        .where(status: 'error')
        .group_by_day(:updated_at, range: start_date..end_date)
        .count,
      content_type_trends: Ragdoll::Core::Models::Document
        .where(created_at: start_date..end_date)
        .group_by_week(:created_at, range: start_date..end_date)
        .group(:document_type)
        .count
    }
  end

  def self.search_usage_trends(days: 30)
    end_date = Date.current
    start_date = end_date - days.days

    {
      daily_searches: Ragdoll::Core::Models::Embedding
        .where(returned_at: start_date..end_date)
        .group_by_day(:returned_at, range: start_date..end_date)
        .sum(:usage_count),
      popular_content_over_time: Ragdoll::Core::Models::Embedding
        .joins(embeddable: :document)
        .where(returned_at: start_date..end_date)
        .group('ragdoll_documents.document_type')
        .group_by_week(:returned_at, range: start_date..end_date)
        .sum(:usage_count),
      embedding_efficiency: Ragdoll::Core::Models::Embedding
        .where('created_at > ?', start_date)
        .group_by_week(:created_at, range: start_date..end_date)
        .average(:usage_count)
    }
  end
end
```

### Custom Dashboard Creation

Framework for building custom monitoring dashboards:

```ruby
class CustomDashboard
  attr_reader :widgets, :refresh_interval

  def initialize(name:, refresh_interval: 30)
    @name = name
    @refresh_interval = refresh_interval
    @widgets = []
  end

  def add_widget(type:, title:, query_method:, **options)
    @widgets << {
      type: type, # :counter, :chart, :table, :gauge
      title: title,
      query_method: query_method,
      options: options
    }
  end

  def render_data
    @widgets.map do |widget|
      {
        type: widget[:type],
        title: widget[:title],
        data: send(widget[:query_method]),
        options: widget[:options],
        last_updated: Time.current.iso8601
      }
    end
  end

  # Example widget methods
  def document_count_by_type
    Ragdoll::Core::Models::Document.group(:document_type).count
  end

  def embedding_usage_distribution
    {
      'Never Used' => Ragdoll::Core::Models::Embedding.where(usage_count: 0).count,
      'Low Usage (1-5)' => Ragdoll::Core::Models::Embedding.where(usage_count: 1..5).count,
      'Medium Usage (6-20)' => Ragdoll::Core::Models::Embedding.where(usage_count: 6..20).count,
      'High Usage (21+)' => Ragdoll::Core::Models::Embedding.where('usage_count > 20').count
    }
  end

  def recent_processing_times
    Ragdoll::Core::Models::Document
      .where('created_at > ?', 24.hours.ago)
      .where(status: 'processed')
      .limit(50)
      .pluck(:created_at, :updated_at)
      .map { |created, updated|
        {
          document_id: created.to_i,
          processing_time: ((updated - created) / 60).round(2) # minutes
        }
      }
  end
end

# Usage example
dashboard = CustomDashboard.new(name: "Ragdoll System Health", refresh_interval: 60)
dashboard.add_widget(type: :counter, title: "Total Documents",
                    query_method: :document_count_by_type)
dashboard.add_widget(type: :chart, title: "Embedding Usage",
                    query_method: :embedding_usage_distribution)
dashboard.add_widget(type: :table, title: "Recent Processing Times",
                    query_method: :recent_processing_times)
```

### Alert Configuration

Set up monitoring alerts based on system thresholds:

```ruby
class AlertSystem
  ALERT_THRESHOLDS = {
    error_rate_percentage: 5.0,
    queue_length: 100,
    processing_time_minutes: 30,
    disk_usage_percentage: 80.0,
    connection_pool_usage: 80.0
  }

  def self.check_system_health
    alerts = []

    # Check error rate
    error_rate = calculate_error_rate
    if error_rate > ALERT_THRESHOLDS[:error_rate_percentage]
      alerts << create_alert(
        severity: :high,
        type: :error_rate,
        message: "Error rate #{error_rate}% exceeds threshold #{ALERT_THRESHOLDS[:error_rate_percentage]}%",
        current_value: error_rate
      )
    end

    # Check queue length
    queue_length = Ragdoll::Core::Models::Document.where(status: 'pending').count
    if queue_length > ALERT_THRESHOLDS[:queue_length]
      alerts << create_alert(
        severity: :medium,
        type: :queue_length,
        message: "Processing queue length #{queue_length} exceeds threshold #{ALERT_THRESHOLDS[:queue_length]}",
        current_value: queue_length
      )
    end

    # Check connection pool usage
    pool_usage = connection_pool_usage_percentage
    if pool_usage > ALERT_THRESHOLDS[:connection_pool_usage]
      alerts << create_alert(
        severity: :high,
        type: :connection_pool,
        message: "Connection pool usage #{pool_usage}% exceeds threshold #{ALERT_THRESHOLDS[:connection_pool_usage]}%",
        current_value: pool_usage
      )
    end

    alerts
  end

  private

  def self.calculate_error_rate
    total_docs = Ragdoll::Core::Models::Document.where('created_at > ?', 24.hours.ago).count
    return 0 if total_docs == 0

    error_docs = Ragdoll::Core::Models::Document.where('created_at > ?', 24.hours.ago)
                                               .where(status: 'error').count
    (error_docs.to_f / total_docs * 100).round(2)
  end

  def self.connection_pool_usage_percentage
    pool = ActiveRecord::Base.connection_pool
    (pool.stat[:checked_out].to_f / pool.stat[:size] * 100).round(2)
  end

  def self.create_alert(severity:, type:, message:, current_value:)
    {
      id: SecureRandom.uuid,
      timestamp: Time.current.iso8601,
      severity: severity,
      type: type,
      message: message,
      current_value: current_value,
      threshold: ALERT_THRESHOLDS[type],
      system: 'ragdoll'
    }
  end
end
```

## Alerting System

Implement comprehensive alerting based on system thresholds and anomaly detection using PostgreSQL and ActiveRecord.

### Threshold-based Alerts

Define and monitor system thresholds:

```ruby
class ThresholdAlerts
  THRESHOLDS = {
    # Processing performance
    error_rate: { warning: 2.0, critical: 5.0 }, # percentage
    queue_length: { warning: 50, critical: 100 },
    avg_processing_time: { warning: 300, critical: 600 }, # seconds

    # System resources
    connection_pool_usage: { warning: 70.0, critical: 85.0 }, # percentage
    disk_usage: { warning: 75.0, critical: 90.0 }, # percentage

    # Content metrics
    unused_embeddings: { warning: 50.0, critical: 70.0 }, # percentage
    search_volume_drop: { warning: 30.0, critical: 50.0 } # percentage decrease
  }

  def self.check_all_thresholds
    alerts = []

    THRESHOLDS.each do |metric, thresholds|
      current_value = send("get_#{metric}")

      if current_value >= thresholds[:critical]
        alerts << create_threshold_alert(metric, :critical, current_value, thresholds[:critical])
      elsif current_value >= thresholds[:warning]
        alerts << create_threshold_alert(metric, :warning, current_value, thresholds[:warning])
      end
    end

    alerts
  end

  private

  def self.get_error_rate
    total = Ragdoll::Core::Models::Document.where('created_at > ?', 24.hours.ago).count
    return 0 if total == 0

    errors = Ragdoll::Core::Models::Document.where('created_at > ?', 24.hours.ago)
                                           .where(status: 'error').count
    (errors.to_f / total * 100).round(2)
  end

  def self.get_queue_length
    Ragdoll::Core::Models::Document.where(status: 'pending').count
  end

  def self.get_avg_processing_time
    recent_docs = Ragdoll::Core::Models::Document
      .where('created_at > ?', 24.hours.ago)
      .where(status: 'processed')
      .pluck(:created_at, :updated_at)

    return 0 if recent_docs.empty?

    times = recent_docs.map { |created, updated| (updated - created).to_i }
    times.sum / times.length
  end

  def self.get_unused_embeddings
    total = Ragdoll::Core::Models::Embedding.count
    return 0 if total == 0

    unused = Ragdoll::Core::Models::Embedding.where(usage_count: 0).count
    (unused.to_f / total * 100).round(2)
  end

  def self.create_threshold_alert(metric, severity, current_value, threshold)
    {
      id: SecureRandom.uuid,
      type: :threshold,
      metric: metric,
      severity: severity,
      current_value: current_value,
      threshold: threshold,
      message: "#{metric.to_s.humanize} #{current_value} exceeds #{severity} threshold #{threshold}",
      timestamp: Time.current.iso8601
    }
  end
end
```

### Anomaly Detection

Detect unusual patterns in system behavior:

```ruby
class AnomalyDetection
  def self.detect_search_anomalies(lookback_days: 7)
    anomalies = []

    # Get baseline search volume
    baseline_searches = daily_search_volume(lookback_days)
    return anomalies if baseline_searches.empty?

    baseline_avg = baseline_searches.values.sum / baseline_searches.length
    baseline_std = calculate_standard_deviation(baseline_searches.values)

    # Check today's volume
    today_volume = daily_search_volume(1).values.first || 0

    # Detect significant deviations (2 standard deviations)
    if (today_volume - baseline_avg).abs > (2 * baseline_std)
      severity = today_volume < baseline_avg ? :warning : :info
      anomalies << {
        type: :search_volume_anomaly,
        severity: severity,
        current_value: today_volume,
        baseline_average: baseline_avg.round(2),
        deviation: ((today_volume - baseline_avg) / baseline_avg * 100).round(2),
        message: "Search volume #{today_volume} deviates significantly from baseline #{baseline_avg.round(2)}"
      }
    end

    anomalies
  end

  def self.detect_processing_anomalies
    anomalies = []

    # Check for unusual processing patterns
    recent_times = Ragdoll::Core::Models::Document
      .where('created_at > ?', 24.hours.ago)
      .where(status: 'processed')
      .pluck(:created_at, :updated_at)
      .map { |created, updated| (updated - created).to_i }

    return anomalies if recent_times.length < 10

    avg_time = recent_times.sum / recent_times.length
    std_dev = calculate_standard_deviation(recent_times)

    # Find outliers (processing times > 3 standard deviations)
    outliers = recent_times.select { |time| (time - avg_time).abs > (3 * std_dev) }

    if outliers.any?
      anomalies << {
        type: :processing_time_outliers,
        severity: :warning,
        outlier_count: outliers.length,
        max_outlier_time: outliers.max,
        baseline_average: avg_time.round(2),
        message: "#{outliers.length} documents had unusual processing times (max: #{outliers.max}s)"
      }
    end

    anomalies
  end

  private

  def self.daily_search_volume(days)
    Ragdoll::Core::Models::Embedding
      .where('returned_at > ?', days.days.ago)
      .group_by_day(:returned_at, last: days)
      .sum(:usage_count)
  end

  def self.calculate_standard_deviation(values)
    return 0 if values.empty?

    mean = values.sum / values.length
    variance = values.sum { |v| (v - mean) ** 2 } / values.length
    Math.sqrt(variance)
  end
end
```

### Notification Channels

Integrate with various notification systems:

```ruby
class NotificationManager
  def self.send_alert(alert, channels: [:log, :webhook])
    channels.each do |channel|
      case channel
      when :log
        log_alert(alert)
      when :webhook
        send_webhook_alert(alert)
      when :email
        send_email_alert(alert)
      when :slack
        send_slack_alert(alert)
      end
    end
  end

  private

  def self.log_alert(alert)
    logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)

    case alert[:severity]
    when :critical
      logger.error "[RAGDOLL CRITICAL] #{alert[:message]}"
    when :warning
      logger.warn "[RAGDOLL WARNING] #{alert[:message]}"
    else
      logger.info "[RAGDOLL INFO] #{alert[:message]}"
    end
  end

  def self.send_webhook_alert(alert)
    webhook_url = ENV['RAGDOLL_WEBHOOK_URL']
    return unless webhook_url

    payload = {
      service: 'ragdoll',
      alert: alert,
      timestamp: Time.current.iso8601,
      environment: ENV['RAILS_ENV'] || 'development'
    }

    # Use Faraday or Net::HTTP to send webhook
    require 'net/http'
    require 'json'

    uri = URI(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    puts "Webhook sent: #{response.code}" if response.code != '200'
  end

  def self.send_slack_alert(alert)
    slack_webhook = ENV['SLACK_WEBHOOK_URL']
    return unless slack_webhook

    color = case alert[:severity]
            when :critical then '#FF0000'
            when :warning then '#FFA500'
            else '#36A64F'
            end

    payload = {
      attachments: [{
        color: color,
        title: "Ragdoll #{alert[:severity].to_s.upcase} Alert",
        text: alert[:message],
        fields: [
          { title: "Metric", value: alert[:metric], short: true },
          { title: "Current Value", value: alert[:current_value], short: true },
          { title: "Timestamp", value: alert[:timestamp], short: false }
        ]
      }]
    }

    # Send to Slack webhook
    # Implementation similar to webhook above
  end
end
```

### Alert Escalation

Implement alert escalation policies:

```ruby
class AlertEscalation
  ESCALATION_RULES = {
    critical: {
      immediate: [:log, :webhook, :slack],
      after_5_minutes: [:email],
      after_15_minutes: [:sms] # if configured
    },
    warning: {
      immediate: [:log],
      after_10_minutes: [:webhook],
      after_30_minutes: [:email]
    }
  }

  def self.process_alert(alert)
    # Store alert for tracking
    alert_record = store_alert(alert)

    # Send immediate notifications
    immediate_channels = ESCALATION_RULES.dig(alert[:severity], :immediate) || [:log]
    NotificationManager.send_alert(alert, channels: immediate_channels)

    # Schedule escalation if needed
    schedule_escalation(alert_record) if alert[:severity] == :critical
  end

  def self.check_escalations
    # This would typically be called by a background job
    unresolved_alerts = get_unresolved_alerts

    unresolved_alerts.each do |alert_record|
      escalate_if_needed(alert_record)
    end
  end

  private

  def self.store_alert(alert)
    # Store in database or memory store for tracking
    {
      id: alert[:id],
      created_at: Time.current,
      alert_data: alert,
      escalation_level: 0,
      resolved_at: nil
    }
  end

  def self.escalate_if_needed(alert_record)
    minutes_since_creation = (Time.current - alert_record[:created_at]) / 60
    severity = alert_record[:alert_data][:severity]

    escalation_rules = ESCALATION_RULES[severity] || {}

    escalation_rules.each do |time_key, channels|
      next unless time_key.to_s.include?('after_')

      threshold_minutes = time_key.to_s.match(/after_(\d+)_minutes/)&.captures&.first.to_i
      next unless threshold_minutes

      if minutes_since_creation >= threshold_minutes &&
         alert_record[:escalation_level] < threshold_minutes

        NotificationManager.send_alert(alert_record[:alert_data], channels: channels)
        alert_record[:escalation_level] = threshold_minutes
      end
    end
  end
end
```

## Integration with External Tools

Ragdoll integrates seamlessly with popular monitoring and observability platforms through standardized metrics and APIs.

### Prometheus Integration

Expose metrics in Prometheus format for scraping:

```ruby
# Prometheus metrics exporter
class PrometheusExporter
  def self.metrics
    output = []

    # Document metrics
    doc_stats = Ragdoll::Core::Models::Document.group(:status).count
    doc_stats.each do |status, count|
      output << "ragdoll_documents_total{status=\"#{status}\"} #{count}"
    end

    # Embedding metrics
    output << "ragdoll_embeddings_total #{Ragdoll::Core::Models::Embedding.count}"
    output << "ragdoll_embeddings_used_total #{Ragdoll::Core::Models::Embedding.where('usage_count > 0').count}"
    output << "ragdoll_searches_total #{Ragdoll::Core::Models::Embedding.sum(:usage_count)}"

    # Processing metrics
    recent_processing_times = Ragdoll::Core::Models::Document
      .where('created_at > ?', 24.hours.ago)
      .where(status: 'processed')
      .pluck(:created_at, :updated_at)
      .map { |created, updated| (updated - created).to_i }

    if recent_processing_times.any?
      avg_time = recent_processing_times.sum / recent_processing_times.length
      output << "ragdoll_avg_processing_time_seconds #{avg_time}"
    end

    # Connection pool metrics
    pool = ActiveRecord::Base.connection_pool
    output << "ragdoll_connection_pool_size #{pool.stat[:size]}"
    output << "ragdoll_connection_pool_checked_out #{pool.stat[:checked_out]}"
    output << "ragdoll_connection_pool_checked_in #{pool.stat[:checked_in]}"

    # Content type distribution
    content_types = Ragdoll::Core::Models::Document.group(:document_type).count
    content_types.each do |type, count|
      output << "ragdoll_documents_by_type{type=\"#{type}\"} #{count}"
    end

    output.join("\n") + "\n"
  end

  # Rack middleware for serving metrics
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if env['PATH_INFO'] == '/metrics' && env['REQUEST_METHOD'] == 'GET'
        metrics_response
      else
        @app.call(env)
      end
    end

    private

    def metrics_response
      metrics = PrometheusExporter.metrics
      [
        200,
        {
          'Content-Type' => 'text/plain; version=0.0.4; charset=utf-8',
          'Content-Length' => metrics.bytesize.to_s
        },
        [metrics]
      ]
    end
  end
end

# Rails integration
# In config/application.rb:
# config.middleware.use PrometheusExporter::Middleware
```

### Grafana Dashboard Templates

JSON dashboard configuration for Grafana:

```ruby
# Grafana dashboard generator
class GrafanaDashboard
  def self.generate_dashboard_json
    {
      "dashboard" => {
        "id" => nil,
        "title" => "Ragdoll Core Monitoring",
        "tags" => ["ragdoll", "rag", "search"],
        "timezone" => "browser",
        "panels" => [
          {
            "id" => 1,
            "title" => "Document Processing Status",
            "type" => "stat",
            "targets" => [
              {
                "expr" => "ragdoll_documents_total",
                "legendFormat" => "{{status}}"
              }
            ],
            "gridPos" => { "h" => 8, "w" => 12, "x" => 0, "y" => 0 }
          },
          {
            "id" => 2,
            "title" => "Search Volume Over Time",
            "type" => "graph",
            "targets" => [
              {
                "expr" => "rate(ragdoll_searches_total[5m])",
                "legendFormat" => "Searches per second"
              }
            ],
            "gridPos" => { "h" => 8, "w" => 12, "x" => 12, "y" => 0 }
          },
          {
            "id" => 3,
            "title" => "Average Processing Time",
            "type" => "singlestat",
            "targets" => [
              {
                "expr" => "ragdoll_avg_processing_time_seconds",
                "legendFormat" => "Seconds"
              }
            ],
            "gridPos" => { "h" => 4, "w" => 6, "x" => 0, "y" => 8 }
          },
          {
            "id" => 4,
            "title" => "Connection Pool Usage",
            "type" => "gauge",
            "targets" => [
              {
                "expr" => "(ragdoll_connection_pool_checked_out / ragdoll_connection_pool_size) * 100",
                "legendFormat" => "Pool Usage %"
              }
            ],
            "gridPos" => { "h" => 4, "w" => 6, "x" => 6, "y" => 8 }
          }
        ],
        "time" => {
          "from" => "now-1h",
          "to" => "now"
        },
        "refresh" => "30s"
      },
      "folderId" => 0,
      "overwrite" => true
    }.to_json
  }
end
```

### New Relic Compatibility

Integrate with New Relic APM and custom metrics:

```ruby
# New Relic custom metrics
class NewRelicIntegration
  def self.record_custom_metrics
    return unless defined?(NewRelic)

    # Document processing metrics
    doc_stats = Ragdoll::Core::Models::Document.group(:status).count
    doc_stats.each do |status, count|
      NewRelic::Agent.record_metric("Custom/Ragdoll/Documents/#{status}", count)
    end

    # Search metrics
    total_searches = Ragdoll::Core::Models::Embedding.sum(:usage_count)
    NewRelic::Agent.record_metric("Custom/Ragdoll/Searches/Total", total_searches)

    # Processing performance
    recent_times = calculate_recent_processing_times
    if recent_times.any?
      avg_time = recent_times.sum / recent_times.length
      NewRelic::Agent.record_metric("Custom/Ragdoll/Processing/AverageTime", avg_time)
    end

    # Embedding efficiency
    used_embeddings = Ragdoll::Core::Models::Embedding.where('usage_count > 0').count
    total_embeddings = Ragdoll::Core::Models::Embedding.count
    efficiency = total_embeddings > 0 ? (used_embeddings.to_f / total_embeddings * 100) : 0
    NewRelic::Agent.record_metric("Custom/Ragdoll/Embeddings/EfficiencyPercent", efficiency)
  end

  # New Relic custom events
  def self.track_search_event(query:, results_count:, processing_time:)
    return unless defined?(NewRelic)

    NewRelic::Agent.record_custom_event('RagdollSearch', {
      query_length: query.length,
      results_count: results_count,
      processing_time_ms: processing_time,
      timestamp: Time.current.to_i
    })
  end

  def self.track_document_processing_event(document:, processing_time:, success:)
    return unless defined?(NewRelic)

    NewRelic::Agent.record_custom_event('RagdollDocumentProcessing', {
      document_type: document.document_type,
      document_size: document.content&.length || 0,
      processing_time_seconds: processing_time,
      success: success,
      embedding_count: document.total_embedding_count,
      timestamp: Time.current.to_i
    })
  end

  private

  def self.calculate_recent_processing_times
    Ragdoll::Core::Models::Document
      .where('created_at > ?', 24.hours.ago)
      .where(status: 'processed')
      .pluck(:created_at, :updated_at)
      .map { |created, updated| (updated - created).to_i }
  end
end

# Background job to send metrics
class MetricsReportingJob < ActiveJob::Base
  queue_as :default

  def perform
    NewRelicIntegration.record_custom_metrics
  end
end

# Schedule regular metrics reporting
# In Rails initializer or similar:
# MetricsReportingJob.set(wait: 5.minutes).perform_later
```

### Custom Monitoring Solutions

Framework for building custom monitoring integrations:

```ruby
class CustomMonitoringAdapter
  attr_reader :config, :client

  def initialize(config = {})
    @config = config
    @client = initialize_client
  end

  def send_metrics(metrics)
    case config[:type]
    when :datadog
      send_datadog_metrics(metrics)
    when :statsd
      send_statsd_metrics(metrics)
    when :influxdb
      send_influxdb_metrics(metrics)
    when :custom_api
      send_custom_api_metrics(metrics)
    else
      Rails.logger.info "Custom metrics: #{metrics.to_json}" if defined?(Rails)
    end
  end

  def collect_all_metrics
    {
      timestamp: Time.current.to_i,
      documents: document_metrics,
      embeddings: embedding_metrics,
      performance: performance_metrics,
      system: system_metrics
    }
  end

  private

  def document_metrics
    {
      total: Ragdoll::Core::Models::Document.count,
      by_status: Ragdoll::Core::Models::Document.group(:status).count,
      by_type: Ragdoll::Core::Models::Document.group(:document_type).count,
      processing_queue_length: Ragdoll::Core::Models::Document.where(status: 'pending').count
    }
  end

  def embedding_metrics
    {
      total: Ragdoll::Core::Models::Embedding.count,
      total_searches: Ragdoll::Core::Models::Embedding.sum(:usage_count),
      used_embeddings: Ragdoll::Core::Models::Embedding.where('usage_count > 0').count,
      recent_searches: Ragdoll::Core::Models::Embedding
        .where('returned_at > ?', 1.hour.ago)
        .sum(:usage_count)
    }
  end

  def performance_metrics
    recent_times = Ragdoll::Core::Models::Document
      .where('created_at > ?', 24.hours.ago)
      .where(status: 'processed')
      .pluck(:created_at, :updated_at)
      .map { |created, updated| (updated - created).to_i }

    {
      avg_processing_time: recent_times.any? ? recent_times.sum / recent_times.length : 0,
      processed_documents_24h: recent_times.length,
      error_rate: calculate_error_rate,
      embedding_efficiency: calculate_embedding_efficiency
    }
  end

  def system_metrics
    pool = ActiveRecord::Base.connection_pool
    {
      connection_pool_size: pool.stat[:size],
      connection_pool_used: pool.stat[:checked_out],
      connection_pool_available: pool.stat[:size] - pool.stat[:checked_out]
    }
  end

  def send_datadog_metrics(metrics)
    # Datadog StatsD format
    metrics.each do |key, value|
      if value.is_a?(Hash)
        value.each do |subkey, subvalue|
          send_metric("ragdoll.#{key}.#{subkey}", subvalue, type: :gauge)
        end
      else
        send_metric("ragdoll.#{key}", value, type: :gauge)
      end
    end
  end

  def send_statsd_metrics(metrics)
    # StatsD protocol implementation
    # Similar to Datadog but with different format
  end

  def send_custom_api_metrics(metrics)
    # Custom HTTP API endpoint
    require 'net/http'
    require 'json'

    uri = URI(config[:endpoint])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{config[:api_key]}" if config[:api_key]
    request.body = metrics.to_json

    response = http.request(request)
    Rails.logger.info "Metrics sent: #{response.code}" if defined?(Rails)
  end
end

# Usage
monitoring = CustomMonitoringAdapter.new(
  type: :datadog,
  api_key: ENV['DATADOG_API_KEY'],
  endpoint: 'https://api.datadoghq.com/api/v1/series'
)

# Collect and send metrics
metrics = monitoring.collect_all_metrics
monitoring.send_metrics(metrics)
```

## Troubleshooting Guides

Comprehensive troubleshooting workflows for common Ragdoll issues, focusing on PostgreSQL and pgvector performance optimization.

### Common Performance Issues

#### Slow Search Performance

**Symptoms:**
- Search queries taking > 2 seconds
- High CPU usage during searches
- Connection pool exhaustion

**Diagnostic Commands:**
```ruby
# Check pgvector index usage
ActiveRecord::Base.connection.execute("
  EXPLAIN ANALYZE
  SELECT * FROM ragdoll_embeddings
  ORDER BY embedding_vector <=> '[0.1,0.2,...]'
  LIMIT 10;
")

# Check index statistics
ActiveRecord::Base.connection.execute("
  SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
  FROM pg_stat_user_indexes
  WHERE tablename = 'ragdoll_embeddings';
")

# Monitor connection pool
pool_stats = ActiveRecord::Base.connection_pool.stat
puts "Pool usage: #{pool_stats[:checked_out]}/#{pool_stats[:size]}"
```

**Resolution Steps:**
1. **Optimize pgvector index:** Ensure IVFFlat index is properly configured
2. **Increase connection pool:** Adjust `pool` setting in database.yml
3. **Enable connection pooling:** Use pgbouncer for high-load scenarios
4. **Query optimization:** Review embedding search filters and limits

```ruby
# Optimize search queries
class SearchOptimizer
  def self.optimize_embedding_search
    # Use index hints for better performance
    Ragdoll::Core::Models::Embedding.connection.execute("
      SET enable_seqscan = OFF;
      SET work_mem = '256MB';
    ")
  end

  def self.batch_similar_searches(query_embeddings, batch_size: 100)
    # Process multiple searches in batches to reduce overhead
    query_embeddings.each_slice(batch_size) do |batch|
      # Process batch of searches
      yield batch
    end
  end
end
```

#### High Memory Usage

**Symptoms:**
- Ruby process memory growth
- PostgreSQL memory pressure
- Frequent garbage collection

**Diagnostic Procedures:**
```ruby
# Memory usage analysis
def analyze_memory_usage
  {
    ruby_process_mb: `ps -o rss= -p #{Process.pid}`.to_i / 1024,
    gc_stats: GC.stat,
    object_counts: ObjectSpace.count_objects,
    connection_pool: ActiveRecord::Base.connection_pool.stat
  }
end

# PostgreSQL memory analysis
ActiveRecord::Base.connection.execute("
  SELECT
    setting AS shared_buffers_mb,
    pg_size_pretty(pg_database_size(current_database())) AS db_size
  FROM pg_settings
  WHERE name = 'shared_buffers';
")
```

**Resolution Strategies:**
1. **Optimize embeddings loading:** Use `select` to load only needed columns
2. **Implement connection pooling:** Use pgbouncer or similar
3. **Tune PostgreSQL memory:** Adjust shared_buffers and work_mem
4. **Regular cleanup:** Implement data retention policies

#### Document Processing Failures

**Symptoms:**
- Documents stuck in 'processing' status
- High error rates
- Background job failures

**Diagnostic Commands:**
```ruby
# Check processing status distribution
processing_status = Ragdoll::Core::Models::Document.group(:status).count
puts "Status distribution: #{processing_status}"

# Find stuck documents
stuck_docs = Ragdoll::Core::Models::Document
  .where(status: 'processing')
  .where('updated_at < ?', 1.hour.ago)

puts "Stuck documents: #{stuck_docs.count}"

# Check recent errors
error_docs = Ragdoll::Core::Models::Document
  .where(status: 'error')
  .where('updated_at > ?', 24.hours.ago)
  .includes(:contents)
```

**Resolution Steps:**
1. **Reset stuck documents:** Change status back to 'pending'
2. **Check job queue:** Ensure ActiveJob backend is running
3. **Review error logs:** Identify common failure patterns
4. **Validate file access:** Ensure file permissions and availability

```ruby
# Recovery procedures
class DocumentRecovery
  def self.reset_stuck_documents
    stuck_docs = Ragdoll::Core::Models::Document
      .where(status: 'processing')
      .where('updated_at < ?', 1.hour.ago)

    stuck_docs.update_all(status: 'pending')
    puts "Reset #{stuck_docs.count} stuck documents"
  end

  def self.retry_failed_documents
    failed_docs = Ragdoll::Core::Models::Document
      .where(status: 'error')
      .where('updated_at > ?', 24.hours.ago)

    failed_docs.each do |doc|
      begin
        doc.update!(status: 'pending')
        # Trigger reprocessing
        Ragdoll::Core::Jobs::ExtractText.perform_later(doc.id)
      rescue => e
        puts "Failed to retry document #{doc.id}: #{e.message}"
      end
    end
  end
end
```

### Diagnostic Procedures

#### System Health Check

```ruby
class SystemHealthCheck
  def self.run_full_diagnostic
    results = {
      timestamp: Time.current.iso8601,
      database: check_database_health,
      models: check_model_integrity,
      performance: check_performance_metrics,
      storage: check_storage_health,
      jobs: check_job_health
    }

    generate_health_report(results)
  end

  private

  def self.check_database_health
    {
      connection_status: ActiveRecord::Base.connected?,
      pool_status: ActiveRecord::Base.connection_pool.stat,
      table_sizes: get_table_sizes,
      index_usage: get_index_usage_stats,
      slow_queries: get_slow_queries
    }
  end

  def self.check_model_integrity
    {
      total_documents: Ragdoll::Core::Models::Document.count,
      orphaned_embeddings: find_orphaned_embeddings,
      missing_content: find_documents_without_content,
      invalid_embeddings: find_invalid_embeddings
    }
  end

  def self.check_performance_metrics
    recent_searches = Ragdoll::Core::Models::Embedding
      .where('returned_at > ?', 1.hour.ago)

    {
      searches_last_hour: recent_searches.sum(:usage_count),
      avg_search_time: calculate_avg_search_time,
      cache_hit_rate: calculate_cache_hit_rate,
      processing_backlog: Ragdoll::Core::Models::Document.where(status: 'pending').count
    }
  end

  def self.get_table_sizes
    ActiveRecord::Base.connection.execute("
      SELECT
        tablename,
        pg_size_pretty(pg_total_relation_size('ragdoll_'||tablename)) as size,
        pg_total_relation_size('ragdoll_'||tablename) as bytes
      FROM pg_tables
      WHERE tablename LIKE 'ragdoll_%'
      ORDER BY pg_total_relation_size('ragdoll_'||tablename) DESC;
    ").to_a
  end

  def self.find_orphaned_embeddings
    # Find embeddings without valid embeddable references
    Ragdoll::Core::Models::Embedding.left_joins(:embeddable)
      .where(ragdoll_contents: { id: nil })
      .count
  end
end
```

#### Performance Profiling

```ruby
class PerformanceProfiler
  def self.profile_search_operation(query, iterations: 100)
    require 'benchmark'

    results = []
    embedding_service = Ragdoll::Core::EmbeddingService.new
    search_engine = Ragdoll::Core::SearchEngine.new(embedding_service)

    # Warm up
    3.times { search_engine.search_documents(query, limit: 10) }

    # Profile multiple iterations
    iterations.times do |i|
      start_time = Time.current

      begin
        search_results = search_engine.search_documents(query, limit: 10)
        end_time = Time.current

        results << {
          iteration: i + 1,
          duration_ms: ((end_time - start_time) * 1000).round(2),
          results_count: search_results.length,
          success: true
        }
      rescue => e
        results << {
          iteration: i + 1,
          error: e.message,
          success: false
        }
      end
    end

    analyze_profile_results(results)
  end

  private

  def self.analyze_profile_results(results)
    successful_results = results.select { |r| r[:success] }

    return { error: "No successful iterations" } if successful_results.empty?

    durations = successful_results.map { |r| r[:duration_ms] }

    {
      total_iterations: results.length,
      successful_iterations: successful_results.length,
      success_rate: (successful_results.length.to_f / results.length * 100).round(2),
      performance: {
        min_ms: durations.min,
        max_ms: durations.max,
        avg_ms: (durations.sum / durations.length).round(2),
        median_ms: durations.sort[durations.length / 2],
        std_dev_ms: calculate_std_dev(durations).round(2)
      },
      percentiles: {
        p50: percentile(durations, 50),
        p90: percentile(durations, 90),
        p95: percentile(durations, 95),
        p99: percentile(durations, 99)
      }
    }
  end
end
```

### Prevention Techniques

#### Proactive Monitoring Setup

```ruby
class PreventiveMaintenance
  def self.setup_monitoring_jobs
    # Schedule regular health checks
    HealthCheckJob.set(cron: '*/15 * * * *').perform_later # Every 15 minutes

    # Schedule daily cleanup
    CleanupJob.set(cron: '0 2 * * *').perform_later # Daily at 2 AM

    # Schedule weekly analytics
    WeeklyReportJob.set(cron: '0 8 * * 1').perform_later # Monday at 8 AM
  end

  def self.optimize_database_settings
    # PostgreSQL optimization for pgvector
    settings = {
      'shared_buffers' => '256MB',
      'work_mem' => '64MB',
      'maintenance_work_mem' => '256MB',
      'effective_cache_size' => '1GB',
      'random_page_cost' => '1.1' # Optimized for SSD
    }

    settings.each do |setting, value|
      ActiveRecord::Base.connection.execute(
        "ALTER SYSTEM SET #{setting} = '#{value}';"
      )
    end

    # Reload configuration
    ActiveRecord::Base.connection.execute("SELECT pg_reload_conf();")
  end

  def self.setup_automated_backups
    # Database backup strategy
    backup_script = <<~SCRIPT
      #!/bin/bash
      # Automated Ragdoll database backup

      DB_NAME="ragdoll_production"
      BACKUP_DIR="/var/backups/ragdoll"
      DATE=$(date +%Y%m%d_%H%M%S)

      # Create backup directory
      mkdir -p $BACKUP_DIR

      # Full database backup
      pg_dump $DB_NAME | gzip > $BACKUP_DIR/ragdoll_$DATE.sql.gz

      # Cleanup old backups (keep 30 days)
      find $BACKUP_DIR -name "ragdoll_*.sql.gz" -mtime +30 -delete

      # Verify backup integrity
      if [ $? -eq 0 ]; then
        echo "Backup completed successfully: ragdoll_$DATE.sql.gz"
      else
        echo "Backup failed!" | mail -s "Ragdoll Backup Failure" admin@example.com
      fi
    SCRIPT

    puts "Add this script to crontab for daily backups:"
    puts "0 3 * * * /path/to/ragdoll_backup.sh"
  end
end
```

#### Configuration Best Practices

```ruby
class ConfigurationValidator
  def self.validate_production_config
    issues = []
    config = Ragdoll.config

    # Database configuration validation
    if config.database_config[:pool] < 20
      issues << "Connection pool size (#{config.database_config[:pool]}) may be too small for production"
    end

    # Search configuration validation
    if config.search[:max_results] > 100
      issues << "max_results (#{config.search[:max_results]}) may impact performance"
    end

    if config.search[:similarity_threshold] < 0.5
      issues << "similarity_threshold (#{config.search[:similarity_threshold]}) may return too many irrelevant results"
    end

    # Analytics configuration
    unless config.search[:enable_analytics]
      issues << "Analytics disabled - monitoring capabilities will be limited"
    end

    # Memory settings validation
    if config.chunking[:text][:max_tokens] > 2000
      issues << "text chunk size (#{config.chunking[:text][:max_tokens]}) may cause memory issues"
    end

    display_validation_results(issues)
  end

  private

  def self.display_validation_results(issues)
    if issues.empty?
      puts "✅ Configuration validation passed"
    else
      puts "⚠️ Configuration issues found:"
      issues.each_with_index do |issue, index|
        puts "#{index + 1}. #{issue}"
      end
    end
  end
end
```

---

## Summary

Ragdoll's monitoring and analytics system provides comprehensive insights into system performance, usage patterns, and health metrics through PostgreSQL-native features and ActiveRecord integration. The built-in analytics track embedding usage for intelligent caching, while the flexible alerting system ensures proactive issue detection.

Key monitoring capabilities include:
- **Usage Analytics**: Search patterns, content popularity, embedding efficiency
- **Performance Metrics**: Processing times, error rates, system resource usage
- **Health Monitoring**: Database status, connection pools, job queue health
- **External Integrations**: Prometheus, Grafana, New Relic, and custom solutions
- **Proactive Alerting**: Threshold-based alerts with escalation policies
- **Troubleshooting Tools**: Diagnostic procedures and automated recovery

All monitoring data leverages PostgreSQL's built-in statistics and pgvector optimization for minimal performance impact while providing maximum visibility into system behavior.

*This document is part of the Ragdoll documentation suite. For immediate help, see the [Quick Start Guide](quick-start.md) or [API Reference](api-client.md).*
