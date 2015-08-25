
# We have selenium test suite that ran 11 hours 45 minutes in sequence on a 2 CPUs 3.5 GB memory VM.
# We configure 35 jobs on Go to run these tests. Tests are partitioned by [TLB] with a time based splitter.
# [TLB] should partition tests equally on build.
# But these jobs randomly ran from 18 minutes to 48 minutes. It seems really badly partitioned.
#
# This is one of scripts I wrote for myself to investigate the problem described above.
# We use ci_reporter to generate junit reports on build.
# This script fetches all junit reports on jobs of last 2 green stages.
# These 2 stages should be next to each other.
# We print latest green stage runtime, then find out what's expected runtime by group all reports by test name in previous green job
# This script also output 2 text files
# One shows job runtime and expected time.
# Another one shows agent runtime and expected time.
# [TLB]: https://github.com/test-load-balancer/tlb

server_url = <go server url>
username = <username>
password = <your password>
pipeline_name = <pipeline name>
stage_name = <stage name>

junit_report_file_name_regex = /TEST-[^.]+.xml/
job_name_regex = /.+/
# job_name_regex = /acceptance_\d+/
stage_count = 2

lib_path = File.expand_path('../../lib', __FILE__)
$:.unshift(lib_path)

require 'goapi'
require 'rexml/document'

class JunitReport < Struct.new(:name, :tests)
  def self.parse(xml)
    root = REXML::Document.new(xml).root
    suite = root.attributes
    tests = []
    root.each_element('//testcase') do |e|
      tests << OpenStruct.new(name: "#{suite['name']}##{e.attributes['name']}", time: e.attributes['time'].to_f)
    end
    new(suite['name'], tests)
  end
end

go = GoAPI.new(server_url, basic_auth: [username, password])

stages = go.stages(pipeline_name, stage_name).select do |s|
  s.result == 'Passed'
end[0..(stage_count-1)]

require 'pstore'
store = PStore.new('pstore')

stages.inject(nil) do |memo_stg_jobs, stage|
  expectation = store.transaction do
    store["jobs-#{go.stage_id(stage)}"] ||= stage.jobs.map do |job|
      if job.result == 'Passed' && job.name =~ job_name_regex
        files = go.artifacts(stage, job.name).map{|a| a.type == 'folder' ? a.files : a}.flatten.select{|f| f.name =~ junit_report_file_name_regex}
        puts "Job #{job.name}, #{files.size} reports"
        tests = files.map { |f| JunitReport.parse(go.artifact(f)).tests }.flatten
        properties = go.job_properties(stage, job.name)
        OpenStruct.new(properties.to_h.merge(name: job.name,
                                             tests: tests,
                                             time: tests.map(&:time).reduce(:+)))
      end
    end.compact
  end
  if memo_stg_jobs
    stg, jobs = memo_stg_jobs
    tests = Hash[expectation.map(&:tests).flatten.map{|t|[t.name, t.time]}]
    reps = jobs.map do |job|
      exp = job.tests.map do |t|
        if time = tests[t.name]
          time
        else
          # puts "unknown test #{t.name} (exp = 0)"
          0
        end
      end.reduce(:+).to_i
      [job, exp, (job.time - exp).to_i]
    end

    puts ""
    puts "#{go.stage_id(stg)} jobs time and expectation"
    puts "  #{'%-14.14s' % 'job name'} time   expected time"
    reps.sort_by{|r| r[2]}.reverse.each do |job, exp, error|
      puts "  #{'%-14.14s' % job.name} #{job.time.to_i} - #{exp}           = #{error} secs          #{job.cruise_agent}"
    end
    File.open("job-time-by-job-#{go.stage_id(stg).gsub(/\//, '-')}.txt", 'w') do |f|
      f.write("Job\tTime\tExpected Time\n")
      reps.sort_by{|r| r[0].name}.each do |job, exp, error|
        f.write("#{job.name}\t#{job.time.to_i}\t#{exp}\n")
      end
    end
    File.open("job-time-by-agent-#{go.stage_id(stg).gsub(/\//, '-')}.txt", 'w') do |f|
      f.write("Agent\tTime\tExpected Time\n")
      reps.sort_by{|r| r[0].cruise_agent}.each do |job, exp, error|
        f.write("#{job.cruise_agent =~ /(bgr\d+)/ ? $1 : job.cruise_agent}\t#{job.time.to_i}\t#{exp}\n")
      end
    end
  end
  [stage, expectation]
end
