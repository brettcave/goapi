
# We have selenium test suite that ran 11 hours 45 minutes in sequence on a 2 CPUs 3.5 GB memory VM.
# We configure 35 jobs on Go to run these tests. Tests are partitioned by [TLB] with a time based splitter.
# [TLB] should partition tests equally on build.
# But these jobs randomly ran from 18 minutes to 48 minutes. It seems really badly partitioned.
#
# This is one of scripts I wrote for myself to investigate the problem described above.
# We use ci_reporter to generate junit reports on build.
# This script fetches all junit reports on jobs of last 8 passed/failed stage.
# Then group all reports by test name, and calculate test runtime range (min..max).
# Print out top 10 bigest range tests info
#
# [TLB]: https://github.com/test-load-balancer/tlb

server_url = <go server url>
username = <username>
password = <your password>
pipeline_name = <pipeline name>
stage_name = <stage name>

junit_report_file_name_regex = /TEST-[^.]+.xml/
job_name_regex = /.+/
# job_name_regex = /acceptance_\d+/
stage_count = 8

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
  s.result == 'Passed' || s.result == 'Failed' # we get failed stage, but we only use passed job later
end[0..(stage_count-1)]

require 'pstore'
store = PStore.new('pstore')

stages.map do |stage|
  reports = store.transaction do
    store["jreports-#{go.stage_id(stage)}"] ||= stage.jobs.map do |job|
      if job.result == 'Passed' && job.name =~ job_name_regex
        files = go.artifacts(stage, job.name).map{|a| a.type == 'folder' ? a.files : a}.flatten.select{|f| f.name =~ junit_report_file_name_regex}
        puts "Job #{job.name}, #{files.size} reports"
        files.map { |f| JunitReport.parse(go.artifact(f)) }
      end
    end.compact.flatten
  end
  
  reports.map(&:tests).flatten.map do |test|
    OpenStruct.new(stage: stage, test: test)
  end
end.flatten.group_by do |st|
  st.test.name
end.map do |test_name, sts|
  ts = sts.map(&:test).map(&:time)
  range = ts.max - ts.min
  OpenStruct.new(name: test_name, sts: sts, range: range)
end.sort_by(&:range).reverse.first(10).each do |test|
  puts "#{test.name}: #{test.range}"
end
