require 'test_helper'

class PlanTest < ActiveSupport::TestCase
  
  setup do
    @org = Org.first
    @template = Template.first
    
    @creator = User.last
    @administrator = User.create!(email: 'administrator@example.com', password: 'password123')
    @editor = User.create!(email: 'editor@example.com', password: 'password123')
    @reader = User.create!(email: 'reader@example.com', password: 'password123')
    
    @plan = Plan.create(title: 'Test Plan', template: @template, grant_number: 'Plan12345',
                        identifier: '000912', description: 'This is a test plan', 
                        principal_investigator: 'John Doe', principal_investigator_identifier: 'ABC',
                        data_contact: 'john.doe@example.com', visibility: 1)
    
    @plan.assign_creator(User.last)
    @plan.save!
  end
  
  # ---------------------------------------------------
  test "required fields are required" do
    assert_not Plan.new.valid?
    assert_not Plan.new(title: 'Testing').valid?, "expected the template field to be required"
    
    # Make sure that the Settings gem is defaulting the title for us
    assert Plan.new(template: @template).valid?, "expected the title field to have been set by default by the Settings gem"
    
    # Ensure the bare minimum and complete versions are valid
    a = Plan.new(title: 'Testing', template: @template)
    assert a.valid?, "expected the 'title', 'template' and at least one 'user' fields to be enough to create an Plan! - #{a.errors.map{|f, m| f.to_s + ' ' + m}.join(', ')}"
  end
  
  # ---------------------------------------------------
  test "dmptemplate returns the template" do
    assert_equal @plan.template, @plan.dmptemplate
  end
  
  # ---------------------------------------------------
  test "correctly creates a new answer" do
    q = @template.phases.first.sections.last.questions.last
    q.answers = []
    q.save!
    
    answer = @plan.answer(q.id)
    assert_equal nil, answer.id, "expected a new Answer"
    assert_equal q.default_value, answer.text, "expected the new Answer to use the Default Answer for the Question"
  end
  
  # ---------------------------------------------------
  test "correctly retrieves the answer for the question" do
    q = @template.phases.first.sections.last.questions.last
    answer = @plan.answer(q.id)
    answer.text = "testing"
    answer.save!
    
    answr = @plan.answer(q.id)
    assert_not answr.id.nil?, "expected the latest Answer"
    assert_equal "testing", answr.text, "expected the Answer returned to have the correct text"
    
    # Check an option based question
    q = QuestionFormat.find_by(option_based: true).questions.first
    p = Plan.create(template: q.section.phase.template, title: 'Testing an option based answer')
    o = QuestionOption.find_by(question: q)
    d = QuestionOption.create(question: q, text: 'default', number: 99, is_default: true)
    a = Answer.create(plan: p, question: q, user: @creator, question_options: [o])
    
    answr = p.answer(q.id, false)
    
    assert_not answr.id.nil?, "expected the Option Based Answer"
    assert_equal [o], answr.question_options, "expected the Answer returned to have the correct options selected"

    # Make sure that default options are selected if creating a new Answer
    a.destroy
    answr = p.answer(q.id)
    assert_equal [d], answr.question_options, "expected the Answer returned to have the correct options selected"
  end
  
  # ---------------------------------------------------
  test "sets the possible guidance groups" do
    @plan.set_possible_guidance_groups
    assert_equal @plan.template.guidance_groups, @plan.guidance_groups, "expected the plan to have inherited the template's guidance groups"
  end
  
  # ---------------------------------------------------
  test "retrieves the guidance for the specified question" do
    template_guidance = @template.org.guidance_groups.collect{|gg| gg.guidances.collect{|g| {orgname: @template.org.name, theme: g.themes.join(','), guidance: g} } }.flatten.uniq
    org_guidance = @creator.org.guidance_groups.collect{|gg| gg.guidances.collect{|g| {orgname: @template.org.name, theme: g.themes.join(','), guidance: g} } }.flatten.uniq
    plan_guidance = @plan.guidance_groups.collect{|gg| gg.guidances.collect{|g| {orgname: @template.org.name, theme: g.themes.join(','), guidance: g} } }.flatten.uniq

    guidances = @plan.guidance_for_question(@template.phases.first.sections.last.questions.last)
    
    template_guidance.each do |hash|
      assert guidances.include?(hash), "expected the guidance to include the following template guidance: #{hash.inspect}"
    end
    
    org_guidance.each do |hash|
      assert guidances.include?(hash), "expected the guidance to include the following org guidance: #{hash.inspect}"
    end
    
    plan_guidance.each do |hash|
      assert guidances.include?(hash), "expected the guidance to include the following plan guidance: #{hash.inspect}"
    end
  end
  
  # ---------------------------------------------------
  test "adds the guidance to a guidance array" do
    # TODO: Skipping because the add_guidance_to_array method doesn't seem to be called from  anywhere
  end
  
  # ---------------------------------------------------
  test "checks whether the specified user can edit the plan" do
    @plan.assign_administrator(@administrator)
    @plan.assign_editor(@editor)
    @plan.assign_reader(@reader)
    
    # TODO: Should the creator be able to edit?
    assert_not @plan.editable_by?(@creator), "expected the creator to NOT be able to edit the plan"
    assert @plan.editable_by?(@editor), "expected the editor to be able to edit the plan"
    assert_not @plan.editable_by?(@administrator), "expected the administrator to NOT be able to edit the plan"
    assert_not @plan.editable_by?(@reader), "expected the reader to NOT be able to edit the plan"
  end
  
  # ---------------------------------------------------
  test "checks whether the specified user can read the plan" do
    @plan.assign_administrator(@administrator)
    @plan.assign_editor(@editor)
    @plan.assign_reader(@reader)
    
    # TODO: Should the creator be able to read?
    assert_not @plan.readable_by?(@creator), "expected the creator to NOT be able to read the plan"
    assert @plan.readable_by?(@editor), "expected the editor to be able to read the plan"
    assert @plan.readable_by?(@administrator), "expected the administrator to be able to read the plan"
    assert @plan.readable_by?(@reader), "expected the reader to be able to read the plan"
  end
  
  # ---------------------------------------------------
  test "checks whether the specified user can administer the plan" do
    @plan.assign_administrator(@administrator)
    @plan.assign_editor(@editor)
    @plan.assign_reader(@reader)
    
    # TODO: Should the creator be able to administer?
    assert_not @plan.administerable_by?(@creator), "expected the creator to NOT be able to administer the plan"
    assert_not @plan.administerable_by?(@editor), "expected the editor to NOT be able to administer the plan"
    assert @plan.administerable_by?(@administrator), "expected the administrator to be able to administer the plan"
    assert_not @plan.administerable_by?(@reader), "expected the reader to NOT be able to administer the plan"
  end
  
  # ---------------------------------------------------
  test "checks that status returns the correct information" do
    q = 0
    @template.phases.first.sections.map{|s| q += s.questions.count }
    
    @plan.answers << Answer.new(user: User.last, text: "testing status",
                                question: @template.phases.first.sections.first.questions.first)
    
    hash = @plan.status
    
    # Expecting the hash to look something like this:
    # -----------------------------------------------
    #{"num_questions"=>13, 
    # "num_answers"=>0, 
    # "sections"=>{
    #   1=>{"questions"=>[1, 2], "num_questions"=>2, "num_answers"=>0}, 
    #   2=>{"questions"=>[3], "num_questions"=>1, "num_answers"=>0}}, 
    # "questions"=>{
    #   1=>{"answer_id"=>nil, "answer_created_at"=>nil, "answer_text"=>nil,
    #       "answer_option_ids"=>nil, "answered_by"=>nil}, 
    #   2=>{"answer_id"=>nil, "answer_created_at"=>nil, "answer_text"=>nil,
    #       "answer_option_ids"=>nil, "answered_by"=>nil}, 
    #   3=>{"answer_id"=>nil, "answer_created_at"=>nil, "answer_text"=>nil,
    #       "answer_option_ids"=>nil, "answered_by"=>nil}}, 
    # "space_used"=>30}
    
    assert_equal q, hash["num_questions"], "expected the number of questions to match"
    assert_equal @plan.answers.count, hash["num_answers"], "expected the number of answers to match"
    
    @template.phases.first.sections.each do |s|
      assert_not hash["sections"][s.id].nil?, "expected section #{s.id} to be in sections portion"
      s.questions.each do |q|
        assert hash["sections"][s.id]["questions"].include?(q.id), "expected section #{s.id}, question #{q.id} to be in section portion"
        
        assert_not hash["questions"][q.id].nil?, "expected question #{q.id} to appear in the questions portion"
      end
    end
  end
  
  # ---------------------------------------------------
  test "checks that last updated time is correct" do
    now = Time.new
    @template.phases.last.updated_at = now
    assert_equal now, @plan.latest_update.to_s
  end
  
  # ---------------------------------------------------
  test "checks that user is a properly assigned as a creator" do
    usr = User.first
    @plan.assign_creator(usr)
    
    assert @plan.administerable_by?(usr), "expected the creator to be able to administer"
    assert @plan.editable_by?(usr), "expected the creator to be able to edit"
    assert @plan.readable_by?(usr), "expected the creator to be able to read"
  end
  
  # ---------------------------------------------------
  test "checks that user is a properly assigned as a editor" do
    usr = User.first
    @plan.assign_editor(usr)
    
    assert_not @plan.administerable_by?(usr), "expected the editor to NOT be able to administer"
    assert @plan.editable_by?(usr), "expected the editor to be able to edit"
    assert @plan.readable_by?(usr), "expected the editor to be able to read"
  end
  
  # ---------------------------------------------------
  test "checks that user is a properly assigned as a reader" do
    usr = User.first
    @plan.assign_reader(usr)
    
    assert_not @plan.administerable_by?(usr), "expected the reader to NOT be able to administer"
    assert_not @plan.editable_by?(usr), "expected the reader to NOT be able to edit"
    assert @plan.readable_by?(usr), "expected the reader to be able to read"
  end
  
  # ---------------------------------------------------
  test "checks that user is a properly assigned as a adminstrator" do
    usr = User.first
    @plan.assign_administrator(usr)
    
    assert @plan.administerable_by?(usr), "expected the adminstrator to be able to administer"
    assert @plan.editable_by?(usr), "expected the adminstrator to be able to edit"
    assert @plan.readable_by?(usr), "expected the adminstrator to be able to read"
  end
  
  # ---------------------------------------------------
  test "name returns the title" do
    assert_equal @plan.title, @plan.name
  end
  
  # ---------------------------------------------------
  test "owner returns the creator" do
    @plan.assign_creator(@creator)
    assert_equal @creator, @plan.owner, "expected the owner to match the creator"
    
    plan = Plan.create!(template: Template.last, title: 'Testing no creator')
    assert plan.owner.nil?, "expected a new plan with no creator assigned to return nil"
  end
  
  # ---------------------------------------------------
  test "checks that last edited matches the latest_update" do
    now = Time.new
    @template.phases.last.updated_at = now
    assert_equal now.to_date, @plan.last_edited
  end
  
  # ---------------------------------------------------
  test "can CRUD Plan" do
    obj = Plan.create(title: 'Testing CRUD', template: Template.where.not(id: @template.id).first, 
                      roles: [Role.new(user: User.last, creator: true)], description: "should change")
    assert_not obj.id.nil?, "was expecting to be able to create a new Plan! - #{obj.errors.map{|f, m| f.to_s + ' ' + m}.join(', ')}"

    obj.description = 'changed'
    obj.save!
    obj.reload
    assert_equal 'changed', obj.description, "Was expecting to be able to update the title of the Plan!"
  
    assert obj.destroy!, "Was unable to delete the Plan!"
  end
  
  # ---------------------------------------------------
  test "can manage has_many relationship with Answers" do
    a = Answer.new(user: User.last, plan: @plan, question: @plan.questions.first, text: 'Test!')
    verify_has_many_relationship(@plan, a, @plan.answers.count)
  end

  # ---------------------------------------------------
  test "can manage has_many relationship with Role" do
    role = Role.new(user: User.first, editor: true)
    verify_has_many_relationship(@plan, role, @plan.roles.count)
  end
  
  # ---------------------------------------------------
  test "can manage has_many relationship with ExportedPlan" do
    ep = ExportedPlan.create(format: ExportedPlan::VALID_FORMATS.last)
    verify_has_many_relationship(@plan, ep, @plan.exported_plans.count)
  end
  
  # ---------------------------------------------------
  test "can manage belongs_to relationship with Template" do
    plan = Plan.new(title: 'Tester')
    verify_belongs_to_relationship(plan, Template.first)
  end
  
end
