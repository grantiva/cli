#!/usr/bin/env ruby
require 'digest'; require 'fileutils'; require 'json'; require 'time'
usage = 'usage: capture-one.rb ROW-DIR LABEL CWD [--timeout SECONDS] [--boot-observation] -- COMMAND...'
abort usage if ARGV.length < 5
row_dir, label, cwd = ARGV.shift(3); timeout_seconds = 30.0; boot_observation = false
until ARGV.empty? || ARGV.first == '--'
  case ARGV.shift
  when '--timeout' then timeout_seconds = Float(ARGV.shift)
  when '--boot-observation' then boot_observation = true
  else abort usage
  end
end
abort 'missing -- separator' unless ARGV.shift == '--'
command = ARGV
abort 'empty command' if command.empty?
abort "cwd does not exist: #{cwd}" unless Dir.exist?(cwd)
abort 'timeout must be positive' unless timeout_seconds.positive?

binary = '/Users/kyle/.grantiva-qa/bin/grantiva'
manifest_path = '/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/completion-candidate4/candidate.json'
runner_home = '/private/tmp/grantiva-cov5-cli-gtwQZB/runner-home'
expected_manifest = '714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783'
manifest_sha = Digest::SHA256.file(manifest_path).hexdigest
abort "manifest mismatch #{manifest_sha}" unless manifest_sha == expected_manifest
manifest = JSON.parse(File.read(manifest_path))
targets = [[binary, manifest.dig('cli','binary','sha256')]]
manifest.dig('cli','bundle','files').each { |e| targets << [File.join(manifest.dig('cli','bundle','path'), e['path']), e['sha256']] }
targets << [manifest.dig('runner','installed','path'), manifest.dig('runner','installed','sha256')]
identity = targets.map do |path, expected|
  actual = Digest::SHA256.file(path).hexdigest
  abort "identity mismatch #{path}: #{actual}" unless actual == expected
  {path: path, expectedSHA256: expected, actualSHA256: actual, matched: true}
end

FileUtils.mkdir_p(row_dir); prefix = File.join(row_dir, label)
abort "capture exists: #{label}" unless Dir.glob("#{prefix}.*").empty?
File.write("#{prefix}.identity.json", JSON.pretty_generate({candidateManifest: manifest_path, candidateManifestSHA256: manifest_sha, files: identity}) + "\n", mode: 'wx')
def boot_observe(prefix, phase)
  pid = Process.spawn('xcrun', 'simctl', 'list', 'devices', 'booted', out: ["#{prefix}.boot-#{phase}.stdout", 'wx'], err: ["#{prefix}.boot-#{phase}.stderr", 'wx'])
  _, status = Process.wait2(pid); abort "boot observation failed at #{phase}" unless status.success?
end
boot_observe(prefix, 'before') if boot_observation

stdout_path = "#{prefix}.stdout"; stderr_path = "#{prefix}.stderr"
env = {'GRANTIVA_RUNNER_HOME'=>runner_home, 'MAESTRO_RUNNER_HOME'=>runner_home, 'GRANTIVA_SESSION_ID'=>'cov5-cli', 'GRANTIVA_API_KEY'=>nil}
started = Time.now.utc
pid = Process.spawn(env, *command, chdir: cwd, pgroup: true, out: [stdout_path, 'wx'], err: [stderr_path, 'wx'])
pgid = Process.getpgid(pid); timed_out = false; term_at = kill_at = status = nil
cleanup_failed = false
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
loop do
  waited = Process.waitpid2(pid, Process::WNOHANG)
  if waited then status = waited[1]; break end
  if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    timed_out = true; term_at = Time.now.utc
    begin Process.kill('TERM', -pgid); rescue Errno::ESRCH; end
    term_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1.0
    group_alive = true
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < term_deadline
      unless status
        waited = Process.waitpid2(pid, Process::WNOHANG)
        status = waited[1] if waited
      end
      group_alive = begin
        Process.kill(0, -pgid)
        true
      rescue Errno::ESRCH
        false
      end
      break unless group_alive
      sleep 0.02
    end
    if group_alive
      kill_at = Time.now.utc
      begin Process.kill('KILL', -pgid); rescue Errno::ESRCH; end
      kill_deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1.0
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < kill_deadline
        unless status
          waited = Process.waitpid2(pid, Process::WNOHANG)
          status = waited[1] if waited
        end
        group_alive = begin
          Process.kill(0, -pgid)
          true
        rescue Errno::ESRCH
          false
        end
        break unless group_alive
        sleep 0.02
      end
    end
    _, status = Process.waitpid2(pid) unless status
    cleanup_failed = group_alive
    break
  end
  sleep 0.02
end
ended = Time.now.utc
group_alive = begin
  Process.kill(0, -pgid)
  true
rescue Errno::ESRCH
  false
end
boot_observe(prefix, 'after') if boot_observation
record = {cwd: cwd, argv: command, environment: env.merge('GRANTIVA_API_KEY'=>'<unset>'), startedAt: started.iso8601(6), endedAt: ended.iso8601(6), timeoutSeconds: timeout_seconds, timedOut: timed_out, pid: pid, processGroupId: pgid, termSentAt: term_at&.iso8601(6), killSentAt: kill_at&.iso8601(6), exited: status.exited?, exitStatus: status.exited? ? status.exitstatus : nil, signaled: status.signaled?, terminationSignal: status.signaled? ? status.termsig : nil, processGroupAliveAfterWait: group_alive, cleanupFailed: cleanup_failed, stdout: stdout_path, stderr: stderr_path, bootObservation: boot_observation, identityEvidence: "#{prefix}.identity.json"}
File.write("#{prefix}.command.json", JSON.pretty_generate(record) + "\n", mode: 'wx')
exit 70 if cleanup_failed
exit(status.exited? ? status.exitstatus : 128 + status.termsig)
