class BatchIsolateJob < IsolateJob
  queue_as ENV["JUDGE0_VERSION"].to_sym

  RESULT_ATTRIBUTES = [
    :status,
    :stdout,
    :stderr,
    :exit_code,
    :exit_signal,
    :message,
    :finished_at
  ].freeze

  def perform(submission_ids)
    submissions_by_id = Submission.where(id: submission_ids).index_by(&:id)
    @submissions = submission_ids.map { |id| submissions_by_id[id] }.compact
    return if @submissions.empty?

    started_at = DateTime.now
    @submissions.each do |current_submission|
      current_submission.update(
        status: Status.process,
        started_at: started_at,
        execution_host: ENV["HOSTNAME"]
      )
    end

    @submission = @submissions.first
    initialize_workdir

    if compile == :failure
      apply_overall_result(submission, nil, nil, nil)
      cleanup
      return
    end

    compile_output = submission.compile_output
    total_time = 0.0
    total_wall_time = 0.0
    peak_memory = 0
    overall_result = submission

    @submissions.each do |current_submission|
      @submission = current_submission
      run_times = []
      run_wall_times = []
      run_memories = []

      submission.number_of_runs.times do
        prepare_test_case
        run
        verify

        run_times << submission.time.to_f
        run_wall_times << submission.wall_time.to_f
        run_memories << submission.memory.to_i

        break if submission.status != Status.ac
      end

      total_time += average(run_times)
      total_wall_time += average(run_wall_times)
      peak_memory = [peak_memory, run_memories.max.to_i].max
      overall_result = submission

      break if submission.status != Status.ac
    end

    overall_result.compile_output = compile_output
    apply_overall_result(overall_result, total_time, total_wall_time, peak_memory)
    cleanup
  rescue Exception => e
    raise e.message if @submissions.blank?

    @submissions.each do |current_submission|
      current_submission.update(message: e.message, status: Status.boxerr, finished_at: DateTime.now)
    end
    cleanup(raise_exception = false) if workdir
  ensure
    call_callbacks
  end

  private

  def prepare_test_case
    File.open(stdin_file, "wb") { |file| file.write(submission.stdin.to_s) }
    [stdout_file, stderr_file, metadata_file].each do |file|
      File.open(file, "wb") { |stream| stream.truncate(0) }
    end
  end

  def apply_overall_result(result, total_time, total_wall_time, peak_memory)
    shared_attributes = RESULT_ATTRIBUTES.each_with_object({}) do |attribute, attributes|
      attributes[attribute] = result.public_send(attribute)
    end
    shared_attributes.merge!(
      compile_output: result.compile_output,
      time: total_time,
      wall_time: total_wall_time,
      memory: peak_memory
    )

    @submissions.each { |current_submission| current_submission.update(shared_attributes) }
  end

  def average(values)
    values.inject(&:+).to_f / values.size
  end

  def call_callbacks
    Array(@submissions).each do |current_submission|
      @submission = current_submission
      call_callback
    end
  end
end
