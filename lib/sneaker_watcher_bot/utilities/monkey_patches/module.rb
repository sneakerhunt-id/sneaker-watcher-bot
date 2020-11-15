class Module
  def subclasses
    self.constants.map do |c| 
      "#{self.name}::#{c}".constantize if self.const_get(c).is_a? Class
    end.compact
  end
end
