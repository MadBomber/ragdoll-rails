Dir[File.join(__dir__, '*.thor')].each { |file| require_relative file }
