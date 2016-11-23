Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_attempts = 10
Delayed::Worker.max_run_time = 10.minutes
Delayed::Worker.read_ahead = 10