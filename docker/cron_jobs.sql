SET ROLE haf_maintainer;
SELECT cron.schedule('dead_app_contexts_auto_detach', '*/30 * * * *', $$CALL hive.proc_perform_dead_app_contexts_auto_detach()$$);
SELECT cron.schedule('delete-job-run-details', '0 12 * * *', $$DELETE FROM cron.job_run_details WHERE end_time < now() - INTERVAL '7 DAYS'$$);
