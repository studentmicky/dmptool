# == Schema Information
#
# Table name: questions
#
#  id                     :integer          not null, primary key
#  default_value          :text(65535)
#  modifiable             :boolean
#  number                 :integer
#  option_comment_display :boolean          default(TRUE)
#  text                   :text(65535)
#  created_at             :datetime
#  updated_at             :datetime
#  question_format_id     :integer
#  section_id             :integer
#
# Indexes
#
#  fk_rails_4fbc38c8c7            (question_format_id)
#  index_questions_on_section_id  (section_id)
#
# Foreign Keys
#
#  fk_rails_...  (question_format_id => question_formats.id)
#  fk_rails_...  (section_id => sections.id)
#

FactoryBot.define do
  factory :question do
    section
    question_format
    text { Faker::Lorem.paragraph }
    sequence(:number)
    modifiable false

    transient do
      options 0
    end

    after(:create) do |question, evaluator|
      create_list(:question_option, evaluator.options, question: question)
    end

    trait :textarea do
      question_format { create(:question_format, :textarea) }
    end

    trait :textfield do
      question_format { create(:question_format, :textfield) }
    end

    trait :radiobuttons do
      question_format { create(:question_format, :radiobuttons) }
    end

    trait :checkbox do
      question_format { create(:question_format, :checkbox) }
    end

    trait :dropdown do
      question_format { create(:question_format, :dropdown) }
    end

    trait :multiselectbox do
      question_format { create(:question_format, :multiselectbox) }
    end

    trait :date do
      question_format { create(:question_format, :date) }
    end

    trait :rda_metadata do
      question_format { create(:question_format, :rda_metadata) }
    end
  end
end
