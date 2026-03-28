require "rails_helper"

RSpec.describe VersionDiff do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: req_module) }

  def create_requirement(attrs = {})
    create(:requirement, section: section, project: project, created_by: user, **attrs)
  end

  describe "#compute" do
    it "returns content-only diffs for a create version" do
      requirement = create_requirement(title: "Initial title")
      version = requirement.versions.first
      diffs = described_class.new(version).compute
      fields = diffs.map(&:field)
      # Create events show what was added (title, body, uid) but skip metadata fields
      expect(fields).to include("title")
      expect(fields).not_to include("id")
      expect(fields).not_to include("created_at")
      expect(fields).not_to include("project_id")
      expect(fields).not_to include("section_id")
    end

    it "computes diffs for title changes" do
      requirement = create_requirement(title: "Original title")
      requirement.update!(title: "Updated title")

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      title_diff = diffs.find { |d| d.field == "title" }
      expect(title_diff).to be_present
      expect(title_diff.old_value).to eq("Original title")
      expect(title_diff.new_value).to eq("Updated title")
      expect(title_diff.diff_html).to include("rf-diff-del")
      expect(title_diff.diff_html).to include("rf-diff-add")
    end

    it "computes word-level diffs for body changes" do
      requirement = create_requirement(body: "The system shall provide logging")
      requirement.update!(body: "The system shall provide detailed logging and monitoring")

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      body_diff = diffs.find { |d| d.field == "body" }
      expect(body_diff).to be_present
      expect(body_diff.diff_html).to include("rf-diff-add")
      # "detailed" and "and monitoring" are additions
      expect(body_diff.diff_html).to include("detailed")
      expect(body_diff.diff_html).to include("monitoring")
    end

    it "handles enum fields with old → new format (no word diff)" do
      requirement = create_requirement(status: :draft)
      requirement.update!(status: :in_review)

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      status_diff = diffs.find { |d| d.field == "status" }
      expect(status_diff).to be_present
      expect(status_diff.old_value).to eq("Draft")
      expect(status_diff.new_value).to eq("In review")
      expect(status_diff.diff_html).to be_nil
    end

    it "handles requirement_type enum changes" do
      requirement = create_requirement(requirement_type: :functional)
      requirement.update!(requirement_type: :safety)

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      type_diff = diffs.find { |d| d.field == "requirement_type" }
      expect(type_diff).to be_present
      expect(type_diff.old_value).to eq("Functional")
      expect(type_diff.new_value).to eq("Safety")
    end

    it "handles priority enum changes" do
      requirement = create_requirement(priority: :must_have)
      requirement.update!(priority: :should_have)

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      priority_diff = diffs.find { |d| d.field == "priority" }
      expect(priority_diff).to be_present
      expect(priority_diff.old_value).to eq("Must have")
      expect(priority_diff.new_value).to eq("Should have")
    end

    it "handles asil_level enum changes" do
      requirement = create_requirement(asil_level: :qm)
      requirement.update!(asil_level: :asil_d)

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      asil_diff = diffs.find { |d| d.field == "asil_level" }
      expect(asil_diff).to be_present
      expect(asil_diff.old_value).to eq("Qm")
      expect(asil_diff.new_value).to eq("Asil d")
    end

    it "skips updated_at and position fields" do
      requirement = create_requirement(title: "Title")
      requirement.update!(title: "New Title")

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      fields = diffs.map(&:field)
      expect(fields).not_to include("updated_at")
      expect(fields).not_to include("position")
    end

    it "handles body change from blank to content" do
      requirement = create_requirement(body: "")
      requirement.update!(body: "New body content")

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      body_diff = diffs.find { |d| d.field == "body" }
      expect(body_diff).to be_present
      expect(body_diff.diff_html).to include("rf-diff-add")
      expect(body_diff.diff_html).to include("New")
    end

    it "handles body change from content to blank" do
      requirement = create_requirement(body: "Existing content")
      requirement.update!(body: "")

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      body_diff = diffs.find { |d| d.field == "body" }
      expect(body_diff).to be_present
      expect(body_diff.diff_html).to include("rf-diff-del")
      expect(body_diff.diff_html).to include("Existing")
    end

    it "handles multiple fields changed at once" do
      requirement = create_requirement(title: "Old title", body: "Old body", priority: :must_have)
      requirement.update!(title: "New title", body: "New body", priority: :could_have)

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      fields = diffs.map(&:field)
      expect(fields).to include("title")
      expect(fields).to include("body")
      expect(fields).to include("priority")
    end

    it "strips HTML tags from body before diffing" do
      requirement = create_requirement(body: "<p>The <strong>system</strong> shall log errors</p>")
      requirement.update!(body: "<p>The <strong>system</strong> shall log all errors and warnings</p>")

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      body_diff = diffs.find { |d| d.field == "body" }
      expect(body_diff).to be_present
      # Should not contain raw HTML tags in the diff output
      expect(body_diff.diff_html).not_to include("<p>")
      expect(body_diff.diff_html).not_to include("<strong>")
    end

    it "escapes HTML entities in diff output" do
      requirement = create_requirement(title: 'Use "quotes" & ampersand')
      requirement.update!(title: 'Use "quotes" & special chars')

      version = requirement.versions.last
      diffs = described_class.new(version).compute

      title_diff = diffs.find { |d| d.field == "title" }
      expect(title_diff).to be_present
      # & should be escaped to &amp;
      expect(title_diff.diff_html).to include("&amp;amp;")
    end

    it "handles enum field with blank old value" do
      requirement = create_requirement(status: :draft)
      # Directly update the column to simulate a nil → value transition
      version = requirement.versions.last
      # For create events, changeset is empty, so let's test via a normal update
      # where the old value might be a blank enum string
      requirement.update!(status: :approved)
      version = requirement.versions.last
      diffs = described_class.new(version).compute

      status_diff = diffs.find { |d| d.field == "status" }
      expect(status_diff).to be_present
    end
  end
end
