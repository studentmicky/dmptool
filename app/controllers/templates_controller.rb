# [+Project:+] DMPRoadmap
# [+Description:+] This controller is responsible for all the actions in the admin interface under templates (e.g. phases, versions, sections, questions, suggested answer) (index; show; create; edit; delete)
# [+Copyright:+] Digital Curation Centre and University of California Curation Center

class TemplatesController < ApplicationController
  respond_to :html
  after_action :verify_authorized

  # GET /dmptemplates
  def admin_index
    authorize Template
    # institutional templates
    all_versions_own_templates = Template.where(org_id: current_user.org_id, customization_of: nil).order(version: :desc)
    current_templates = {}
    # take most recent version of each template
    all_versions_own_templates.each do |temp|
      if current_templates[temp.dmptemplate_id].nil?
        current_templates[temp.dmptemplate_id] = temp
      end
    end
    @templates_own = current_templates.values
    @other_published_version = {}
    current_templates.keys.each do |dmptemplate_id|
      @other_published_version[dmptemplate_id] = Template.where(org_id: current_user.org_id, dmptemplate_id: dmptemplate_id, published: true).present?
    end

    # funders templates
    funders_templates = {}
    Org.includes(:templates).funder.each do |org|
      org.templates.where(customization_of: nil, published: true).order(version: :desc).each do |temp|
        if funders_templates[temp.dmptemplate_id].nil?
          funders_templates[temp.dmptemplate_id] = temp
        end
      end
    end

    @templates_funders = funders_templates.values
    # are any funder templates customized
    @templates_customizations = {}
    Template.where(org_id: current_user.org_id, customization_of: funders_templates.keys).order(version: :desc).each do |temp|
      if @templates_customizations[temp.customization_of].nil?
        @templates_customizations[temp.customization_of] = {}
        @templates_customizations[temp.customization_of][:temp] = temp
        @templates_customizations[temp.customization_of][:published] = temp.published
      else
        @templates_customizations[temp.customization_of][:published] = @templates_customizations[temp.customization_of][:published] || temp.published
      end
    end
  end


  # GET /dmptemplates/1
  def admin_template
    @template = Template.find(params[:id])
    # check to see if this is a funder template needing customized
    if @template.org_id != current_user.org_id
      # definitely need to deep_copy the given template
      new_customization = Template.deep_copy(@template)
      new_customization.org_id = current_user.org_id
      new_customization.published = false
      new_customization.customization_of = @template.dmptemplate_id
      # need to mark all Phases, questions, sections as not-modifiable
      new_customization.phases.includes(sections: :questions).each do |phase|
        phase.modifiable = false
        phase.save!
        phase.sections.each do |section|
          section.modifiable = false
          section.save!
          section.questions.each do |question|
            question.modifiable = false
            question.save!
          end
        end
      end
      customizations = Template.includes(phases: [sections: [questions: :suggested_answers ]]).where(org_id: current_user.org_id, customization_of: @template.dmptemplate_id).order(version: :desc)
      if customizations.present?
        # existing customization to port over
        max_version = customizations.first
        new_customization.dmptemplate_id = max_version.dmptemplate_id
        new_customization.version = max_version.version + 1
        # here we rip the customizations out of the old template
        # First, we find any customized phases or sections
        max_version.phases.each do |phase|
          # check if the phase was added as a customization
          if phase.modifiable
            # deep copy the phase and add it to the template
            phase_copy = Phase.deep_copy(phase)
            phase_copy.number = new_customization.phases.length + 1
            phase_copy.template_id = new_customization.id
            phase_copy.save!
          else
            # iterate over the sections to see if any of them are customizations
            phase.sections.each do |section|
              if section.modifiable
                # this is a custom section
                section_copy = Section.deep_copy(section)
                customization_phase = new_customization.phases.includes(:sections).where(number: phase.number).first
                section_copy.phase_id = customization_phase.id
                # custom sections get added to the end
                section_copy.number = customization_phase.sections.length + 1
                # section from phase with corresponding number in the main_template
                section_copy.save!
              else
                # not a customized section, iterate over questions
                customization_phase = new_customization.phases.includes(sections: [questions: :suggested_answers]).where(number: phase.number).first
                customization_section = customization_phase.sections.where(number: section.number).first
                section.questions.each do |question|
                  # find corresponding question in new template
                  customization_question = customization_section.questions.where(number: question.number).first
                  # apply suggested_answers
                  question.suggested_answers.each do |suggested_answer|
                    suggested_answer_copy = SuggestedAnswer.deep_copy(suggested_answer)
                    suggested_answer_copy.org_id = current_user.org_id
                    suggested_answer_copy.question_id = customization_question.id
                    suggested_answer_copy.save!
                  end
                  # guidance attached to a question is also a form of customization
                  # It will soon become an annotation of the question, and be combined with
                  # suggested answers
                  customization_question.guidance = customization_question.guidance + question.guidance
                  customization_question.save!
                end
              end
            end
          end
        end
      else
        # first time customization
        new_customization.version = 0
        new_customization.dmptemplate_id = loop do
          random = rand 2147483647  # max int field in psql
          break random unless Template.exists?(dmptemplate_id: random)
        end
      end
      new_customization.save!
      @template = new_customization
    end
    # needed for some post-migration edge cases
    # some customized templates which were edited
    if @template.published
      new_version = Template.deep_copy(@template)
      new_version.version = @template.version + 1
      new_version.published = false
      new_version.save!
      @template = new_version
    end
    authorize @template
  end


  # PUT /dmptemplates/1
  def admin_update
    @template = Template.find(params[:id])
    authorize @template
    if @template.published?
      # published templates cannot be edited
      redirect_to admin_template_template_path(@template), notice: I18n.t('org_admin.templates.read_only') and return
    end
    @template.description = params["template-desc"]
    if @template.update_attributes(params[:template])
      if @template.published
        # create a new template version if this template became published
        new_version = Template.deep_copy(@template)
        new_version.version = @template.version + 1
        new_version.published = false
        new_version.save!
      end
      redirect_to admin_index_template_path(), notice: I18n.t('org_admin.templates.updated_message')
    else
      render action: "edit"
    end
  end


  # GET /dmptemplates/new
  def admin_new
    authorize Template
  end


  # POST /dmptemplates
  # creates a new template with version 0 and new dmptemplate_id
  def admin_create
    @template = Template.new(params[:template])
    @template.org_id = current_user.org_id
    @template.description = params['template-desc']
    @template.published = false
    @template.version = 0
    # Generate a unique identifier for the dmptemplate_id
    @template.dmptemplate_id = loop do
      random = rand 2147483647
      break random unless Template.exists?(dmptemplate_id: random)
    end
    authorize @template
    if @template.save
      redirect_to admin_template_template_path(@template), notice: I18n.t('org_admin.templates.created_message')
    else
      render action: "admin_new"
    end
  end


  # DELETE /dmptemplates/1
  def admin_destroy
    @template = Template.find(params[:id])
    authorize @template
    @template.destroy
    redirect_to admin_index_template_path
  end

  # GET /templates/1
  def admin_template_history
    @template = Template.find(params[:id])
    authorize @template
    @templates = Template.where(dmptemplate_id: @template.dmptemplate_id).order(:version)
  end



  # PHASES

  #show and edit a phase of the template
  def admin_phase
    @phase = Phase.find(params[:id])
    authorize @phase.template
    @edit = params[:edit] == "true" ? true : false
        #verify if there are any sections if not create one
    @sections = @phase.sections
    if !@sections.any?() || @sections.count == 0
      @section = @phase.sections.build
      @section.phase = @phase
      @section.title = ''
      @section.number = 1
      @section.published = true
      @section.modifiable = true
      @section.save
      @new_sec = true
    end
    #verify if section_id has been passed, if so then open that section
    if params.has_key?(:section_id)
      @open = true
      @section_id = params[:section_id].to_i
    end
    if params.has_key?(:question_id)
      @question_id = params[:question_id].to_i
    end
  end


  #preview a phase
  def admin_previewphase
    @phase = Phase.find(params[:id])
    authorize @phase.template
    @template = @phase.template
  end


  #add a new phase to a template
  def admin_addphase
    @template = Template.find(params[:id])
    @phase = Phase.new
    authorize @template
    @phase.number = @template.phases.count + 1
  end


  #create a phase
  def admin_createphase
    @phase = Phase.new(params[:phase])
    authorize @phase.template
    @phase.description = params["phase-desc"]
    @phase.modifiable = true
    if @phase.save
      redirect_to admin_phase_template_path(id: @phase.id, edit: 'true'), notice: I18n.t('org_admin.templates.created_message')
    else
      render action: "admin_phase"
    end
  end


  #update a phase of a template
  def admin_updatephase
    @phase = Phase.find(params[:id])
    authorize @phase.template
    @phase.description = params["phase-desc"]
    if @phase.update_attributes(params[:phase])
      redirect_to admin_phase_template_path(@phase), notice: I18n.t('org_admin.templates.updated_message')
    else
      render action: "admin_phase"
    end
  end

  #delete a phase
  def admin_destroyphase
    @phase = Phase.find(params[:phase_id])
    authorize @phase.template
    @template = @phase.template
    @phase.destroy
    redirect_to admin_template_template_path(@template), notice: I18n.t('org_admin.templates.destroyed_message')
  end

# SECTIONS
  #create a section
  def admin_createsection
    @section = Section.new(params[:section])
    authorize @section.phase.template
    @section.description = params["section-desc"]
    @section.modifiable = true
    if @section.save
      redirect_to admin_phase_template_path(id: @section.phase_id,
        :section_id => @section.id, edit: 'true'), notice: I18n.t('org_admin.templates.created_message')
    else
      render action: "admin_phase"
    end
  end


  #update a section of a template
  def admin_updatesection
    @section = Section.find(params[:id])
    authorize @section.phase.template
    @section.description = params["section-desc-#{params[:id]}"]
    @phase = @section.phase
    if @section.update_attributes(params[:section])
      redirect_to admin_phase_template_path(id: @phase.id, section_id: @section.id , edit: 'true'), notice: I18n.t('org_admin.templates.updated_message')
    else
      render action: "admin_phase"
    end
  end


  #delete a section and questions
  def admin_destroysection
    @section = Section.find(params[:section_id])
    authorize @section.phase.template
    @phase = @section.phase
    @section.destroy
    redirect_to admin_phase_template_path(id: @phase.id, edit: 'true' ), notice: I18n.t('org_admin.templates.destroyed_message')
  end


#  QUESTIONS

  #create a question
  def admin_createquestion
    @question = Question.new(params[:question])
    authorize @question.section.phase.template
    @question.guidance = params["new-question-guidance"]
    @question.default_value = params["new-question-default-value"]
    if @question.save!
      redirect_to admin_phase_template_path(id: @question.section.phase_id, section_id: @question.section_id, question_id: @question.id, edit: 'true'), notice: I18n.t('org_admin.templates.created_message')
    else
      render action: "admin_phase"
    end
  end

  #update a question of a template
  def admin_updatequestion
    @question = Question.find(params[:id])
    authorize @question.section.phase.template
    @question.guidance = params["question-guidance-#{params[:id]}"]
    @question.default_value = params["question-default-value-#{params[:id]}"]
    @section = @question.section
    @phase = @section.phase
    if @question.update_attributes(params[:question])
      redirect_to admin_phase_template_path(id: @phase.id, section_id: @section.id, question_id: @question.id, edit: 'true'), notice: I18n.t('org_admin.templates.updated_message')
    else
      render action: "admin_phase"
    end
  end

  #delete question
  def admin_destroyquestion
    @question = Question.find(params[:question_id])
    authorize @question.section.phase.template
    @section = @question.section
    @phase = @section.phase
    @question.destroy
    redirect_to admin_phase_template_path(id: @phase.id, section_id: @section.id, edit: 'true'), notice: I18n.t('org_admin.templates.destroyed_message')
  end


  #SUGGESTED ANSWERS
  #create suggested answers
  def admin_createsuggestedanswer
    @suggested_answer = SuggestedAnswer.new(params[:suggested_answer])
    authorize @suggested_answer.question.section.phase.template
    if @suggested_answer.save
      redirect_to admin_phase_template_path(id: @suggested_answer.question.section.phase_id, section_id: @suggested_answer.question.section_id, question_id: @suggested_answer.question.id, edit: 'true'), notice: I18n.t('org_admin.templates.created_message')
    else
      render action: "admin_phase"
    end
  end


  #update a suggested answer of a template
  def admin_updatesuggestedanswer
    @suggested_answer = SuggestedAnswer.find(params[:id])
    authorize @suggested_answer.question.section.phase.template
    @question = @suggested_answer.question
    @section = @question.section
    @phase = @section.phase
    if @suggested_answer.update_attributes(params[:suggested_answer])
      redirect_to admin_phase_template_path(id: @phase.id, section_id: @section.id, question_id: @question.id, edit: 'true'), notice: I18n.t('org_admin.templates.updated_message')
    else
      render action: "admin_phase"
    end
  end

  #delete a suggested answer
  def admin_destroysuggestedanswer
    @suggested_answer = SuggestedAnswer.find(params[:suggested_answer])
    authorize @suggested_answer.question.section.phase.template
    @question = @suggested_answer.question
    @section = @question.section
    @phase = @section.phase
    @suggested_answer.destroy
    redirect_to admin_phase_template_path(id: @phase.id, section_id: @section.id, edit: 'true'), notice: I18n.t('org_admin.templates.destroyed_message')
  end

end