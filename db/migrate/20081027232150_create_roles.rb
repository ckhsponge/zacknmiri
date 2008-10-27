class CreateRoles < ActiveRecord::Migration
  def self.up
    create_table :roles do |t|
      t.integer "uid", :null => false
      t.string "text", :null => "false", :default => ""
      t.timestamps
    end
  end

  def self.down
    drop_table :roles
  end
end
