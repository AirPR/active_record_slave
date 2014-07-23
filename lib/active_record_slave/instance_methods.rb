module ActiveRecordSlave
  # Select Methods
  SELECT_METHODS = [:select, :select_all, :select_one, :select_rows, :select_value, :select_values]

  # In case in the future we are forced to intercept connection#execute if the
  # above select methods are not sufficient
  #   SQL_READS = /\A\s*(SELECT|WITH|SHOW|CALL|EXPLAIN|DESCRIBE)/i

  module InstanceMethods
    SELECT_METHODS.each do |select_method|
      # Database Adapter method #exec_query is called for every select call
      # Replace #exec_query with one that calls the slave connection instead
      eval <<-METHOD
      def #{select_method}_with_slave_reader(sql, name = nil, *args)
        if active_record_slave_read_from_master?
          #{select_method}_without_slave_reader(sql, name, *args)
        else
          # Calls are going against the Slave now, prevent an infinite loop
          ActiveRecordSlave.read_from_master do
            Slave.connection.#{select_method}(sql, "Slave: \#{name || 'SQL'}", *args)
          end
        end
      end
      METHOD
    end

    # Returns whether to read from the master database
    def active_record_slave_read_from_master?
      # Read from master when forced by thread variable, or
      # in a transaction and not ignoring transactions
      ActiveRecordSlave.read_from_master? ||
        (open_transactions > 0) && !ActiveRecordSlave.ignore_transactions?
    end

  end
end

