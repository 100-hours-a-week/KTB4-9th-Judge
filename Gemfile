source 'https://rubygems.org'

gem 'rails', '~> 6.1'
gem 'pg', '~> 1.2'

gem 'active_model_serializers', '~> 0.10'
gem 'enumerations', '~> 2.3'
gem 'httparty', '~> 0.21'
gem 'pry-byebug', '~> 3.9'
gem 'pry-rails', '~> 0.3'
gem 'puma', '~> 5.6'
gem 'rack-cors', '~> 1.1'
gem 'redis', '< 4.6'
gem 'resque', '~> 2.6'
gem 'resque-scheduler', '~> 4.10'
gem 'will_paginate', '~> 3.2'

group :development do
  gem 'annotate', '~> 3.0'
  gem 'listen', '~> 3.2'
end

# 분산 트레이싱. 런타임이 Ruby 2.7이라 2.7을 지원하는 마지막 버전대로 고정한다.
# OTEL_EXPORTER_OTLP_ENDPOINT가 있을 때만 켜진다(config/initializers/opentelemetry.rb).
gem 'opentelemetry-sdk', '~> 1.2.1'
gem 'opentelemetry-exporter-otlp', '~> 0.24.2'
gem 'opentelemetry-instrumentation-rails', '~> 0.25.0'
gem 'opentelemetry-instrumentation-pg', '~> 0.23.0'
gem 'opentelemetry-instrumentation-redis', '~> 0.24.1'
gem 'opentelemetry-instrumentation-resque', '~> 0.3.1'
