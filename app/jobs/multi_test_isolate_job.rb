class MultiTestIsolateJob < IsolateJob
  queue_as ENV["JUDGE0_VERSION"].to_sym

  def perform(submission_id)
    @submission = Submission.find(submission_id)
    submission.update(status: Status.process, started_at: DateTime.now, execution_host: ENV["HOSTNAME"])

    initialize_workdir
    if compile == :failure
      cleanup
      return
    end

    total_time = 0.0
    total_wall_time = 0.0
    peak_memory = 0

    submission.decoded_test_cases.each do |test_case|
      prepare_test_case(test_case[:stdin])
      run
      verify(test_case[:expected_output])

      total_time += submission.time.to_f
      total_wall_time += submission.wall_time.to_f
      peak_memory = [peak_memory, submission.memory.to_i].max

      break if submission.status != Status.ac
    end

    submission.time = total_time
    submission.wall_time = total_wall_time
    submission.memory = peak_memory
    submission.save
    cleanup
  rescue Exception => e
    raise e.message unless submission
    submission.update(message: e.message, status: Status.boxerr, finished_at: DateTime.now)
    cleanup(raise_exception = false) if workdir
  ensure
    call_callback
  end

  private

  def prepare_test_case(stdin)
    File.open(stdin_file, "wb") { |file| file.write(stdin.to_s) }
    [stdout_file, stderr_file, metadata_file].each do |file|
      File.open(file, "wb") { |stream| stream.truncate(0) }
    end
  end
end
