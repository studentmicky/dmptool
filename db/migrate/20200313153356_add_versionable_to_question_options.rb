class AddVersionableToQuestionOptions < ActiveRecord::Migration
  def change
    add_column :question_options, :versionable_id, :string, limit: 36

    add_index :question_options, :versionable_id
  end
end
