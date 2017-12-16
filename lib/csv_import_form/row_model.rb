module CsvImportForm
  class RowModel
    include ActiveModel::Model
    class_attribute :fields

    def self.define_field(column_name)
      self.fields ||= []
      self.fields << column_name
      attr_accessor column_name
    end
  end
end
