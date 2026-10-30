class ContactsController < ApplicationController
  before_action :set_contact, only: %i[edit update destroy]

  def index
    page = WorkspacePage.new(Current.user.contacts.searching(params[:q]).order(:name, :id), params[:page])
    render inertia: "contacts/Index", props: { contacts: -> { page.records.map(&:recipient_props) }, pagination: page.props, query: params[:q].to_s }
  end
  def new
    @contact = Current.user.contacts.new
    render_editor
  end
  def create
    @contact = Current.user.contacts.new(contact_params)
    if @contact.save
      redirect_to contacts_path, notice: "Contact saved. Choose it as a recipient from any invoice draft."
    else
      redirect_to new_contact_path, inertia: { errors: @contact.errors }
    end
  end
  def edit = render_editor
  def update
    if @contact.update(contact_params)
      redirect_to contacts_path, notice: "Contact updated. Existing invoice recipients stay as saved."
    else
      redirect_to edit_contact_path(@contact), inertia: { errors: @contact.errors }
    end
  end
  def destroy
    @contact.destroy!
    redirect_to contacts_path, notice: "Contact deleted. Existing invoices keep their saved recipient details."
  end
  private
  def set_contact = @contact = Current.user.contacts.find(params[:id])
  def contact_params = params.require(:contact).permit(*Contact::FIELDS)
  def render_editor
    render inertia: "contacts/Edit", props: { contact: @contact.as_json(only: [ :id, *Contact::FIELDS ]) }
  end
end
