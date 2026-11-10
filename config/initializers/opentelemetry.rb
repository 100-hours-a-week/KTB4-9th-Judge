# OpenTelemetry 분산 트레이싱.
#
# OTEL_EXPORTER_OTLP_ENDPOINT가 없으면 아무것도 하지 않는다. 로컬과 기존 배포는 동작이 바뀌지 않는다.
# 설정은 모두 표준 환경 변수로 받는다.
#   OTEL_EXPORTER_OTLP_ENDPOINT  예: http://alloy.monitoring:4318 (Ruby 내보내기는 OTLP/HTTP만 지원)
#   OTEL_SERVICE_NAME            예: cosmos-judge-api, cosmos-judge-worker
#   OTEL_TRACES_SAMPLER(_ARG)    예: parentbased_traceidratio, 0.1
#   OTEL_JUDGE_SPAN_PROCESSOR    simple이면 span이 끝날 때 바로 보낸다.
#
# Resque는 작업마다 자식 프로세스를 fork하고 exit!로 끝낸다. 배치 처리기는 자식이 끝날 때
# 남은 span을 보내지 못하므로 worker에는 OTEL_JUDGE_SPAN_PROCESSOR=simple을 준다.
if ENV['OTEL_EXPORTER_OTLP_ENDPOINT'].present?
  require 'opentelemetry/sdk'
  require 'opentelemetry/exporter/otlp'
  require 'opentelemetry/instrumentation/rails'
  require 'opentelemetry/instrumentation/pg'
  require 'opentelemetry/instrumentation/redis'
  require 'opentelemetry/instrumentation/resque'

  OpenTelemetry::SDK.configure do |c|
    c.use 'OpenTelemetry::Instrumentation::Rails'
    # 제출 소스 코드와 입력값이 SQL에 실리므로 값은 가린다.
    c.use 'OpenTelemetry::Instrumentation::PG', db_statement: :obfuscate
    c.use 'OpenTelemetry::Instrumentation::Redis'
    # judge-api가 넣은 작업을 같은 트레이스의 자식으로 이어 붙인다.
    c.use 'OpenTelemetry::Instrumentation::Resque', propagation_style: :child

    if ENV['OTEL_JUDGE_SPAN_PROCESSOR'] == 'simple'
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new
        )
      )
    end
  end
end
