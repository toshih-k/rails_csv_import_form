module CsvImportForm
  class FormModel
    include ActiveModel::Model
    class_attribute :model_mappings
    class_attribute :row_model_class

    attr_accessor :upload
    attr_accessor :records

    def has_error?
      self.errors.count > 0
    end

    protected
    def self.bind_row_model(row_model)
      self.row_model_class = row_model
    end

    def self.map_model(name, options)
      self.model_mappings ||= {}
      self.model_mappings[name] = options
    end

    def read_from_file(filename, options={})
      self.records = []
      CSV.foreach( filename, options).with_index(1) do |line, i|
         next if i==1
         attributes = self.class.row_model_class.fields.map.with_index do |field_name, i|
           [field_name, line[i]]
         end.to_h
         record = self.class.row_model_class.new(attributes)
         self.records << record
      end
    end

    def read_from_array(array_list)
      self.records = []
      array_list.each.with_index(1) do |line, i|
        next if i==1
        attributes = self.class.row_model_class.fields.map.with_index do |field_name, i|
         [field_name, line[i]]
        end.to_h
        record = self.class.row_model_class.new(attributes)
        self.records << record
      end
    end

    def pick_and_aggregate_data(mapping_name, &skip_condition)
      result = self.records
      .reject(&skip_condition)
      .map do |record|
        get_necessary_fields(mapping_name).map do |field_name|
          [field_name, record.send(field_name)]
        end.to_h
      end
      if self.class.model_mappings[mapping_name][:aggregate]
        result = result.uniq
      end

      # 全て空のレコードは無視する
      result = result.delete_if do |record|
        record.values.all?{|value| value.nil?}
      end

      # 重複チェック
      if !self.class.model_mappings[mapping_name][:unique_key].blank?
        unique_key = self.class.model_mappings[mapping_name][:unique_key]
        error_keys = result
        .group_by do |r|
          r[unique_key]
        end.map do |k, v|
          [k, v.length]
        end.reject do |k, v|
          v < 2
        end.map do |k, v|
          k
        end
        if error_keys.length > 0
          msg = self.class.model_mappings[mapping_name][:unique_key_error_message]
          self.errors.add(:base, "#{msg}[#{error_keys.join(',')}]")
        end
      end
      result
    end

    def save_data(mapping_name, records, login_user_instance)
      options = self.class.model_mappings[mapping_name]
      skip_update_id = nil
      id_list = []
      if !options[:skip_update_id_proc].nil?
        skip_update_id = options[:skip_update_id_proc].call(login_user_instance)
        id_list << skip_update_id
      end
      model_class = mapping_name.to_s.classify.constantize
      records.each do |record|
        keys = get_keys(mapping_name, record)
        if keys.nil?
          dbrec = model_class.new
        else
          dbrec = model_class.find_by(keys) || model_class.new(keys)
        end
        # 権限等このタイミングで更新したくないレコードが存在する場合
        # 更新対象から除外しかつ削除対象にならないようid_listには追加
        if !dbrec.new_record? and dbrec.id == skip_update_id
          next
        end
        dbrec.attributes = get_values(mapping_name, record)
        unless options[:relay_to].nil?
          options[:relay_to].each do |relay_model_name|
            relay_keys = get_keys(relay_model_name, record)
            if relay_keys.nil?
              raise RuntimeError.new('関連レコードに対して一意に検索可能なフィールドが設定されていません。')
            end
            relay_item = relay_model_name.to_s.classify.constantize.find_by(relay_keys)
            next if relay_item.nil?
            dbrec["#{relay_model_name}_id"] = relay_item.id
          end
        end
        dbrec.save!
        id_list << dbrec.id
      end
      if options[:delete]
        # 削除対象にしたくないレコードをここでセット
        unless options[:skip_delete_id_proc].nil?
          id_list << options[:skip_delete_id_proc].call(login_user_instance)
        end
        model_class.where.not(id: id_list).delete_all
      end
    end

    private
    def get_necessary_fields(mapping_name)
      fields = self.class.model_mappings[mapping_name][:mapping].keys
      unless self.class.model_mappings[mapping_name][:relay_to].nil?
        self.class.model_mappings[mapping_name][:relay_to].each do |relay_to_mapping_name|
          relay_to_option = self.class.model_mappings[relay_to_mapping_name]
          relay_to_option[:match_fields].each do |field_name|
            fields << relay_to_option[:mapping].invert[field_name]
          end
        end
      end
      fields
    end

    #
    # レコードのうちユニークkeyとなるフィールドをハッシュで取得
    #
    def get_keys(mapping_name, record)
      options = self.class.model_mappings[mapping_name]
      return nil if options[:match_fields].nil?
      options[:mapping].select do |key, value|
        options[:match_fields].include?(value)
      end
      .map do |key, value|
        [value, record[key]]
      end
      .to_h
    end

    #
    # レコードのうちユニークkey以外のフィールドをハッシュで取得
    #
    def get_values(mapping_name, record)
      options = self.class.model_mappings[mapping_name]
      fields = options[:mapping]
      if !options[:match_fields].nil?
        fields = fields.select do |key, value|
          !options[:match_fields].include?(value)
        end
      end
      fields.map do |key, value|
        [value, record[key]]
      end
      .to_h
    end
  end
end
