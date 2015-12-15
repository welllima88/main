
module PosxmlParser
  module Instructions
    def flow_if(jump_point, variable1, operator, variable2)
      posxml_conditional(jump_point, variable1, operator, variable2)
    end

    def flow_else(jump_point)
      posxml_jump!(jump_point.value)
    end

    def flow_end_if
    end

    def flow_execute(file_name)
      posxml_load!(file_name.value)
    end

    def flow_function(jump_point, function_name)
      posxml_jump!(jump_point.value)
    end

    def flow_function_call(jump_point, function_name)
      # Push current
      posxml_push_function(number - 1)
      posxml_jump!(jump_point.value)
    end

    def flow_function_end
      posxml_pop_function
    end

    def flow_while(jump_point, variable1, operator, variable2)
      posxml_conditional(jump_point, variable1, operator, variable2)
    end

    def flow_while_break(jump_point)
      posxml_jump!(jump_point.value)
    end

    def flow_while_end(jump_point)
      posxml_jump!(jump_point.value)
    end

    def util_exit
      posxml_load!(file_main)
    end

    def string_variable(value, index)
      posxml_define_variable(value.value, index.value)
    end

    def integer_variable(value, index)
      posxml_define_variable(value.value, index.value)
    end

    def file_download(file_name, remote_path, variable)
      variable.value = -5
      return unless socket?

      file_path = posxml_file_path(file_name.value)
      variable.value = Device::Transaction::Download.request_file(remote_path.value, file_path)
    end

    def file_size(file_name, result)
      path = posxml_file_path(file_name.value)
      result.value = File.exists?(path) ? File.size(path) : -1
    end

    def file_delete(file_name)
      begin
        File.delete(file_name.value)
      rescue Errno::ENOENT
      end
    end

    def file_rename(old, new, variable)
      if File.exists?(old.value)
        File.rename(old.value, new.value)
        variable.value = 0 # OK
      else
        variable.value = -1 # NOT OK
      end
    end

    def file_edit_db(file_name, key, value)
      posxml_write_db(file_name.value, key.value, value.value)
    end

    def file_read_db(file_name, key, string)
      string.value = posxml_read_db(file_name.value, key.value)
    end

    def network_send(buffer, size, variable)
      if socket? && socket.send(buffer.to_s, 0) > 0
        variable.value = 1
      else
        variable.value = 0
      end
    end

    def network_receive(buffer, max_size, bytes, variable)
      variable.value = 0
      buffer.value = ""
      if socket?
        timeout = Time.now + Device::Setting.uclreceivetimeout.to_i
        loop do
          buffer.value << socket.read(bytes.value) if socket.bytes_available > 0
          break if (timeout > Time.now) || buffer.value.size >= max_size.to_i
          usleep 500_000
        end
      end
    ensure
      # 1 - Success; 0 - Failure
      bytes.value = buffer.value.size
      variable.value = 1 if bytes.value > 0
    end

    def network_host_disconnect
      socket.close if socket?
    end

    def network_pre_connect(variable)
      variable.value = Device::Network.attach
      if variable.value == 0
        socket.close if socket?
        @socket = Device::Network.socket
      end
    end

    #TODO Refactory need
    def datetime_get(format_string, string)
      format = format_string.value
      format.match(/yy/) == nil ? format = format.gsub(/y/, "\%y") : format = format.gsub(/yy/, "\%Y")

      format = format.gsub(/M/, "\%m")
      format = format.gsub(/d/, "\%d")
      format = format.gsub(/h/, "\%H")
      format = format.gsub(/m/, "\%M")
      format = format.gsub(/s/, "\%S")
      #To fix month and minutes confusion
      format = format.gsub(/%%M/, "\%m")

      datetime = Time.now

      string.value = datetime.strftime(format)
    end

    def util_math(result, operator, variable1, variable2)
      result.value = variable1.compare(operator, variable2)
    end

    def string_to_hex(string, hex)
      hex.value = string.value.to_s.unpack('H*').first
    end

    def string_hex_to_string(hex, string)
      string.value = [hex.value.to_s].pack('H*')
    end

    def string_join(string1, string2, result)
      result.value = "#{string1.value}#{string2.value}"
    end

    def binary_convert_to_integer(base, string, integer)
      case base.value
      when "2"
        integer.value = string.value.to_i(2)
      when "10"
        integer.value = string.value.to_i(16)
      when "16"
        integer.value = string.value.to_i(16)
      end
    end

    def integer_convert_to_binary(number, base, size, variable)
      binary = number.to_i.to_s(base.to_i)
      if binary.size < size.to_i
        if base.to_i == 2
          binary = ("0" * (size.to_i/4 - binary.size)) + binary
        else
          binary = ("0" * (size.to_i - binary.size)) + binary
        end
      end
      variable.value = binary.upcase
    end

    def integer_to_string(integer, string)
      string.value = integer.value.to_s
    end

    def integer_operator(operator, integer)
      if operator.value == "++"
        integer.value = integer.to_i + 1
      elsif operator.value == "--"
        integer.value = integer.to_i - 1
      end
    end

    def string_length(string, variable)
      variable.value = string.value.to_s.size
    end

    def string_string_substring(string, start, length, substring)
      substring.value = string.value[start.value.to_i, length.value.to_i]
    end

    def string_to_integer(string, integer)
      integer.value = string.value.to_i
    end

    def string_char_at(string, index, variable)
      variable.value = string.value[index.to_i]
    end

    def string_element_at(string, index, delimiter, variable)
      variable.value = string.value.split(delimiter.value)[index.to_i]
    end

    def string_elements(string, delimiter, variable)
      variable.value = string.to_s.split(delimiter.value).size
    end

    def string_find(str, sub, start, variable)
      str = str.value
      sub = sub.value
      start = start.value.to_i
      if str && str.size > start
        index = str.index(sub)
        variable.value = index == nil ? -1 : (index >= start ? index - start : -1)
      else
        variable.value = -1
      end
    end

    def string_get_value_by_key(string, key, variable)
      index = string.value.index(key.value+"=")
      if index
        from_index = string.value[index+key.value.size+1..-1]
        last_quote_index = from_index.rindex("\"")
        from_index = from_index[0..last_quote_index] + "," + from_index[last_quote_index..-1]
        variable.value = from_index.split("\",")[0]
      end
    end

    def string_trim(str, variable)
      strip = str.value.strip
      variable.value = strip if strip
    end

    def string_insert_at(string, insert, index, delimiter, variable)
      parts    = string.value.split(delimiter.value)
      index    = index.to_i
      head     = parts[0..(index-1)]
      head[-1] = head[-1]+insert.value
      tail     = parts[(index)..-1]
      variable.value = head.join(delimiter.value) + tail.join(delimiter.value)
    end

    def string_pad(origin, char, align, length, destination)
      length = length.to_i - origin.value.size
      chars = char.value * length
      case align.value
      when "left"
        destination.value = chars + origin.value
      when "right"
        destination.value = origin.value + chars
      end
    end

    def string_remove_at(original, index, delimiter, variable)
      parts = original.value.split(delimiter.value)
      parts.delete_at(index.value.to_i)
      variable.value = parts.join(delimiter.value)
    end

    def string_replace(original, old, new, variable)
      sub = original.value.gsub old.value, new.value
      variable.value = sub ? sub : original.value
    end

    def string_replace_at(string, replace, index, delimiter, variable)
      parts = string.value.split(delimiter.value)
      index = index.to_i
      parts[index] = replace.value
      variable.value = parts.join(delimiter.value)
    end

    def string_substring(index, source, destination, char, variable)
      parts = source.to_s.split(char.to_s)
      if index.to_i >= 0 && parts.size > index.to_i
        destination.value = parts[index.to_i]
        variable.value = index.to_i
      else
        variable.value =  -1
      end
    end

    def iso8583_init_field_table(filename,variablereturn)
      @iso8583_filename = filename.value
      variablereturn.value = 0
    end

    def iso8583_init_message(format,id,variablemessage,variablereturn)
      begin
        iso_format = format.value == "ASCII" ? ISO8583::N : ISO8583::LL_BCD
        @iso_klass = ISO8583::FileParser.build_klass([iso_format, {length: 4}],
          {id.value.to_i => ""}, posxml_file_path(@iso8583_filename))
        variablereturn.value = 0
      rescue
        variablereturn.value = -801
      end
    end

    def iso8583_analyze_message(format,size,variablemessage,variableid,variablereturn)
      begin
        iso_format = format.value == "ASCII" ? ISO8583::N : ISO8583::LL_BCD
        @iso_klass.instance_eval { 
          mti_format iso_format, :length => 4 
          mti variableid.to_i, ""
        }
        @iso_analyzed = @iso_klass.parse(variablemessage.value, true)
        variablereturn.value = 0
      rescue
        variablereturn.value = -806
      end
    end

    def iso8583_end_message(variablesize,variablereturn)
      begin
        @iso_binary = @iso.to_b
        variablesize.value = @iso_binary.size
        variablereturn.value = 0
      rescue
        variablereturn.value = -801
      end
    end

    def iso8583_put_field(fieldnumber,type,value,variablereturn)
      begin
        @iso[fieldnumber.to_i] = value.value
        variablereturn.value = 0
      rescue
        variablereturn.value = -801
      end
    end

    def iso8583_get_field(fieldnumber,type,variablevalue,variablereturn)
      begin
        variablevalue.value = @iso_analyzed[fieldnumber.to_i]
        variablereturn.value = 0
      rescue
        variablereturn.value = -801
      end
    end

    # TODO Implement others channels
    #  0: Size of the response message
    # -1: Channel unknown or not implemented
    # -2: Failed to connect to the host or while attempting to dial
    # -3: Failed to send send the message to the host authorizer
    # -4: Failed to receive the size of the response message
    def iso8583_transact_message(channel,header,trailler,isomsg,variableresponse,variablereturn)
      # -1: Channel unknown or not implemented
      return(variablereturn.value = -1) unless channel.value == "NAC"

      # -2: Failed to connect to the host or while attempting to dial
      return(variablereturn.value = -2) if Device::Network.connected? != 0

      message      = "#{header.value}#{@iso_binary}#{trailler.value}"
      size         = message.size + 2
      message      = "#{[size].pack("n*")}#{message}"
      isomsg.value = message

      # Send
      # -3: Failed to send send the message to the host authorizer
      return(variablereturn.value = -3) unless socket.send(message)

      # Receive
      variablereturn.value = socket.read(2).to_s.unpack("n*")[0].to_s

      # -4: Failed to receive the size of the response message
      return(variablereturn.value = -4) if variableresponse.value.empty?

      timeout = Time.now + Device::Setting.uclreceivetimeout.to_i
      attempts = 1
      loop do
        variableresponse.value << socket.read(size) if socket.bytes_available > 0
        break if variableresponse.value.size >= size
        if (timeout > Time.now)
          # -5: Failed to receive the response message
          break(variablereturn.value = -5) if attempts >= 3
          timeout = Time.now + Device::Setting.uclreceivetimeout.to_i
          attempts+=1
        end
        usleep 500_000
      end
    end

    def iso8583_transact_message_sub_field(channel,header,trailler,variablereturn)
      # Deprecated, shouldn't be implemented
    end

    def card_get_variable(msg1, msg2, min, max, var)
      # Should be implemented by platform
    end

    def card_get(msg1, msg2, min, max, var)
      # Deprecated, shouldn't be implemented
    end

    def card_read(key, card, timeout, result)
      # Should be implemented by platform
    end

    def card_system_input_transaction(key, card, timeout, var, keyboard, type)
      # Should be implemented by platform
    end

    def interface_menu(variable, options)
      # Should be implemented by platform
    end

    def interface_menu_header(header, options, timeout_header, timeout, variable)
      # Should be implemented by platform
    end

    def interface_display(column, line, text)
      # Should be implemented by platform
    end

    def interface_display_bitmap(file_name, variable)
      # Should be implemented by platform
    end

    def interface_clean_display
      # Should be implemented by platform
    end

    def interface_system_get_touchscreen(axis_x, axis_y, variable)
      # Should be implemented by platform
    end

    def print(message)
      # Should be implemented by platform
    end

    def print_big(message)
      # Should be implemented by platform
    end

    def print_barcode(number)
      # Should be implemented by platform
    end

    def print_bitmap(filename)
      # Should be implemented by platform
    end

    def print_check_paper_out(variable)
      # Should be implemented by platform
    end

    def print_paper_feed
      # Should be implemented by platform
    end

    def input_float(variable,line,column,message)
      # Should be implemented by platform
    end

    def input_integer(variable,line,column,message,minimum,maximum)
      # Should be implemented by platform
    end

    def input_option(variable,line,column,message,minimum,maximum)
      # Should be implemented by platform
    end

    def input_money(variable,line,column,message)
      # Should be implemented by platform
    end

    def input_format(variable, line, column, message, type)
      # Should be implemented by platform
    end

    def input_getvalue(linecaption,columncaption,caption,lineinput,columninput,minimum,maximum,allowsempty,variablereturn)
      # Should be implemented by platform
    end

    def crypto_encryptdecrypt(message,key,cryptotype,type,variablereturn)
      # Should be implemented by platform
    end

    def crypto_lrc(buffer,size,variablereturn)
      # Should be implemented by platform
    end

    def crypto_xor(buffer1,buffer2,size,variablereturn)
      # Should be implemented by platform
    end

    def crypto_crc(buffer,size,crctype,variablereturn)
      # Should be implemented by platform
    end

    def file_list(dir,listfilename,variablereturn)
      # Should be implemented by platform
    end

    def file_system_space(dir, type, variable)
      # Should be implemented by platform
    end

    def file_open(mode,filename,variablehandle)
      # Should be implemented by platform
    end

    def file_close(handle)
      # Should be implemented by platform
    end

    def file_read(handle,size,variablebuffer,variablereturn)
      # Should be implemented by platform
    end

    def file_write(handle,size,buffer)
      # Should be implemented by platform
    end

    def file_read_by_index(filename,index,variablekey,variablevalue,variablereturn)
      # Should be implemented by platform
    end

    def file_unzip(filename,variablereturn)
      # Should be implemented by platform
    end

    def serial_open_port(port,rate,configuration,variablereturn)
      # Should be implemented by platform
    end

    def serial_read_port(variablehandle,variablebuffer,bytes,timeout,variablereturn)
      # Should be implemented by platform
    end

    def serial_write_port(variablehandle,buffer)
      # Should be implemented by platform
    end

    def serial_close_port(variablehandle)
      # Should be implemented by platform
    end

    def datetime_adjust(datetime)
      # Deprecated, shouldn't be implemented
    end

    def datetime_calculate(operation,type,date,greaterdate,value,variablereturn)
      # Should be implemented by platform
    end

    def network_pre_dial(option,variablestatus)
      # Should be implemented by platform
    end

    def network_shutdown_modem
      # Should be implemented by platform
    end

    def network_check_gprs_signal(variablestatus)
      # Should be implemented by platform
    end

    def network_ping(host,variablereturn)
      # Should be implemented by platform
    end

    def pinpad_open(type,variableserialnumber,variablereturn)
      # Should be implemented by platform
    end

    def pinpad_display(message)
      # Should be implemented by platform
    end

    def pinpad_getkey(message,timeout,variablereturn)
      # Should be implemented by platform
    end

    def pinpad_getpindukpt(message,type,pan,maxlen,variablereturnpin,variablereturnksn,variablereturn)
      # Should be implemented by platform
    end

    def pinpad_loadipek(ipek,ksn,type,variablereturn)
      # Should be implemented by platform
    end

    def pinpad_close(message)
      # Should be implemented by platform
    end

    def emv_open(variablereturn,mkslot,pinpadtype,pinpadwk,showamount)
      # Should be implemented by platform
    end

    def emv_close(variablereturn)
      # Should be implemented by platform
    end

    def emv_loadtables(acquirer,variablereturn)
      # Should be implemented by platform
    end

    def emv_settimeout(seconds,variablereturn)
      # Should be implemented by platform
    end

    def emv_cleanstructures
      # Should be implemented by platform
    end

    def emv_adddata(type,parameter,value,variablereturn)
      # Should be implemented by platform
    end

    def emv_getinfo(type,parameter,value)
      # Should be implemented by platform
    end

    def emv_inittransaction(variablereturn)
      # Should be implemented by platform
    end

    def emv_processtransaction(variablereturn,ctls)
      # Should be implemented by platform
    end

    def emv_finishtransaction(variablereturn)
      # Should be implemented by platform
    end

    def emv_removecard(variablereturn)
      # Should be implemented by platform
    end

    def smartcard_insert_card(slot,variablereturn)
      # Should be implemented by platform
    end

    def smartcard_reader_close(slot,variablereturn)
      # Should be implemented by platform
    end

    def smartcard_reader_start(slot,variablereturn)
      # Should be implemented by platform
    end

    def smartcard_transmit_APDU(slot,header,lc,datafield,le,variabledatafieldresponse,variableSW,variablereturn)
      # Should be implemented by platform
    end

    def util_system_beep
      # Should be implemented by platform
    end

    def util_system_checkbattery
      # Should be implemented by platform
    end

    def util_system_info(type,variablereturn)
      # Should be implemented by platform
    end

    def util_system_restart
      # Should be implemented by platform
    end

    def util_system_qrcode(filename, input, size, version)
      # Should be implemented by platform
    end

    def util_wait_key
      # Should be implemented by platform
    end

    def util_wait_key_timeout(timeout_seconds)
      # Should be implemented by platform
    end

    def util_wait(timeout_milliseconds)
      # Should be implemented by platform
    end

    def util_read_key(timeout_milliseconds, variable)
      # Should be implemented by platform
    end

    def util_parse_ticket(productmenu,ticket,message,literal,variablereturn)
      # Should be implemented by platform
    end

    private
    def socket?
      socket
    end
  end
end
