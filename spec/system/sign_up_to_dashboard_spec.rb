require "rails_helper"

RSpec.describe "Sign up to dashboard flow", type: :system do
  describe "new user sign up" do
    it "allows a new user to sign up with valid credentials" do
      visit new_user_registration_path

      fill_in "First name", with: "Jane"
      fill_in "Last name", with: "Smith"
      fill_in "Email", with: "jane@example.com"
      fill_in "Password", with: "password123"
      fill_in "Confirm password", with: "password123"
      click_button "Create account"

      expect(User.find_by(email: "jane@example.com")).to be_present
    end

    it "shows validation errors with invalid credentials" do
      visit new_user_registration_path

      fill_in "First name", with: ""
      fill_in "Last name", with: ""
      fill_in "Email", with: "invalid"
      fill_in "Password", with: "short"
      fill_in "Confirm password", with: "mismatch"
      click_button "Create account"

      expect(page).to have_content("error")
    end

    it "redirects new user to organization setup after sign up" do
      visit new_user_registration_path

      fill_in "First name", with: "Jane"
      fill_in "Last name", with: "Smith"
      fill_in "Email", with: "jane@example.com"
      fill_in "Password", with: "password123"
      fill_in "Confirm password", with: "password123"
      click_button "Create account"

      expect(page).to have_current_path(new_organization_path)
      expect(page).to have_content("Create Your Organization")
    end
  end

  describe "organization setup" do
    let(:user) { create(:user) }

    before do
      login_as(user, scope: :user)
    end

    it "shows the organization setup page for users without an organization" do
      visit root_path

      expect(page).to have_current_path(new_organization_path)
      expect(page).to have_content("Create Your Organization")
      expect(page).to have_field("Organization name")
    end

    it "allows creating an organization with a valid name" do
      visit new_organization_path

      fill_in "Organization name", with: "Acme Engineering"
      click_button "Create Organization"

      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Organization created successfully")
      expect(Organization.find_by(name: "Acme Engineering")).to be_present
    end

    it "creates an admin membership for the user" do
      visit new_organization_path

      fill_in "Organization name", with: "Acme Engineering"
      click_button "Create Organization"

      org = Organization.find_by(name: "Acme Engineering")
      membership = Membership.find_by(user: user, organization: org)
      expect(membership).to be_present
      expect(membership.role).to eq("admin")
    end

    it "shows validation errors for blank organization name" do
      visit new_organization_path

      fill_in "Organization name", with: ""
      click_button "Create Organization"

      expect(page).to have_content("Create Your Organization")
    end

    it "auto-generates a slug from the organization name" do
      visit new_organization_path

      fill_in "Organization name", with: "Acme Engineering"
      click_button "Create Organization"

      org = Organization.find_by(name: "Acme Engineering")
      expect(org.slug).to eq("acme-engineering")
    end
  end

  describe "dashboard" do
    let(:user) { create(:user) }
    let(:organization) { create(:organization) }

    before do
      create(:membership, user: user, organization: organization, role: :admin)
      login_as(user, scope: :user)
    end

    it "shows the dashboard with welcome message" do
      visit root_path

      expect(page).to have_content("Welcome back, #{user.first_name}")
      expect(page).to have_content("Organization overview and team performance")
    end

    it "shows getting started empty state when no projects exist" do
      visit root_path

      expect(page).to have_content("Get started with ReqForge")
      expect(page).to have_content("Create First Project")
      expect(page).to have_content("Create a project")
      expect(page).to have_content("Add requirements")
      expect(page).to have_content("Build traceability")
    end

    it "shows stat cards when projects exist" do
      create(:project, organization: organization, name: "Test Project")
      visit root_path

      expect(page).to have_content("Projects")
      expect(page).to have_content("Requirements")
      expect(page).to have_content("Active Reviews")
      expect(page).to have_content("Team Members")
      expect(page).to have_content("New Project")
    end

    it "shows the sidebar navigation" do
      visit root_path

      expect(page).to have_content("Dashboard")
      expect(page).to have_content("Projects")
      expect(page).to have_content(organization.name)
    end
  end

  describe "complete flow: sign up → organization creation → dashboard" do
    it "walks a new user through the entire onboarding flow" do
      # Step 1: Sign up
      visit new_user_registration_path
      fill_in "First name", with: "Alice"
      fill_in "Last name", with: "Johnson"
      fill_in "Email", with: "alice@example.com"
      fill_in "Password", with: "securepassword"
      fill_in "Confirm password", with: "securepassword"
      click_button "Create account"

      # Step 2: Redirected to organization setup
      expect(page).to have_current_path(new_organization_path)
      expect(page).to have_content("Create Your Organization")

      # Step 3: Create organization
      fill_in "Organization name", with: "Johnson Automotive"
      click_button "Create Organization"

      # Step 4: Arrives at dashboard
      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Organization created successfully")
      expect(page).to have_content("Welcome back, Alice")
      expect(page).to have_content("Johnson Automotive")

      # Verify data was created correctly
      user = User.find_by(email: "alice@example.com")
      expect(user).to be_present
      expect(user.first_name).to eq("Alice")

      org = Organization.find_by(name: "Johnson Automotive")
      expect(org).to be_present

      membership = Membership.find_by(user: user, organization: org)
      expect(membership).to be_present
      expect(membership.role).to eq("admin")
    end
  end

  describe "sign in flow for existing user with organization" do
    let(:user) { create(:user, password: "password123") }
    let(:organization) { create(:organization) }

    before do
      create(:membership, user: user, organization: organization, role: :admin)
    end

    it "signs in and goes directly to dashboard" do
      visit new_user_session_path

      fill_in "Email", with: user.email
      fill_in "Password", with: "password123"
      click_button "Sign in"

      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Welcome back, #{user.first_name}")
    end
  end
end
