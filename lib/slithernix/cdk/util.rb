module Slithernix
  module Cdk
    module Util
      def self.is_process_alive?(pid)
        begin
          Process.kill(0, pid)
          true
        rescue Errno::ESRCH
          false
        rescue Errno::EPERM
          true
        end
      end

      def self.is_thread_dead_or_dying?(t)
        [ "aborting", false, nil ].include? t.status
      end
    end
  end
end
