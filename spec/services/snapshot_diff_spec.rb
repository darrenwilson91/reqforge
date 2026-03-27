require "rails_helper"

RSpec.describe SnapshotDiff do
  let(:organization) { create(:organization) }
  let(:project) { create(:project, organization: organization) }
  let(:req_module) { create(:requirement_module, project: project) }
  let(:section) { create(:section, requirement_module: req_module) }
  let(:user) { create(:user) }
  let(:review) { create(:review, project: project, created_by: user) }
  let(:requirement) do
    create(:requirement,
      project: project,
      section: section,
      created_by: user,
      title: "Original title",
      body: "Original body text",
      requirement_type: :functional,
      status: :draft,
      priority: :must_have,
      asil_level: :asil_b)
  end
  let!(:review_item) do
    item = create(:review_item, review: review, requirement: requirement)
    item.snapshot_requirement!
    item
  end

  subject { described_class.new(review_item) }

  describe "#compute" do
    it "returns diff fields for all tracked attributes" do
      fields = subject.compute
      field_names = fields.map(&:field)

      expect(field_names).to include("uid", "title", "body", "requirement_type", "status",
                                     "priority", "asil_level", "module_name", "section_name")
    end

    context "when nothing has changed" do
      it "marks all fields as unchanged" do
        fields = subject.compute
        expect(fields.any?(&:changed)).to be false
      end

      it "returns nil diff_html for unchanged text fields" do
        title_field = subject.compute.find { |f| f.field == "title" }
        expect(title_field.diff_html).to be_nil
      end
    end

    context "when title has changed" do
      before { requirement.update!(title: "Updated title") }

      it "marks title as changed" do
        title_field = subject.compute.find { |f| f.field == "title" }
        expect(title_field.changed).to be true
      end

      it "generates word-level diff HTML" do
        title_field = subject.compute.find { |f| f.field == "title" }
        expect(title_field.diff_html).to include("rf-diff-del")
        expect(title_field.diff_html).to include("rf-diff-add")
      end
    end

    context "when body has changed" do
      before { requirement.update!(body: "New body content") }

      it "marks body as changed" do
        body_field = subject.compute.find { |f| f.field == "body" }
        expect(body_field.changed).to be true
      end

      it "provides snapshot and current values" do
        body_field = subject.compute.find { |f| f.field == "body" }
        expect(body_field.snapshot_value).to eq("Original body text")
        expect(body_field.current_value).to eq("New body content")
      end

      it "generates word-level diff HTML" do
        body_field = subject.compute.find { |f| f.field == "body" }
        expect(body_field.diff_html).to include("rf-diff-del")
        expect(body_field.diff_html).to include("rf-diff-add")
      end
    end

    context "when an enum field has changed" do
      before { requirement.update!(status: :approved) }

      it "marks status as changed" do
        status_field = subject.compute.find { |f| f.field == "status" }
        expect(status_field.changed).to be true
      end

      it "humanizes enum values" do
        status_field = subject.compute.find { |f| f.field == "status" }
        expect(status_field.snapshot_value).to eq("Draft")
        expect(status_field.current_value).to eq("Approved")
      end

      it "does not generate diff_html for enum fields" do
        status_field = subject.compute.find { |f| f.field == "status" }
        expect(status_field.diff_html).to be_nil
      end
    end

    context "when requirement_type changes" do
      before { requirement.update!(requirement_type: :safety) }

      it "detects the change" do
        type_field = subject.compute.find { |f| f.field == "requirement_type" }
        expect(type_field.changed).to be true
        expect(type_field.snapshot_value).to eq("Functional")
        expect(type_field.current_value).to eq("Safety")
      end
    end

    context "when priority changes" do
      before { requirement.update!(priority: :could_have) }

      it "detects the change" do
        field = subject.compute.find { |f| f.field == "priority" }
        expect(field.changed).to be true
        expect(field.snapshot_value).to eq("Must have")
        expect(field.current_value).to eq("Could have")
      end
    end

    context "when asil_level changes" do
      before { requirement.update!(asil_level: :asil_d) }

      it "detects the change" do
        field = subject.compute.find { |f| f.field == "asil_level" }
        expect(field.changed).to be true
        expect(field.snapshot_value).to eq("Asil b")
        expect(field.current_value).to eq("Asil d")
      end
    end

    context "when snapshot is blank" do
      it "returns empty array" do
        blank_item = create(:review_item, review: review, requirement: create(:requirement, project: project, section: section, created_by: user))
        diff = described_class.new(blank_item)
        expect(diff.compute).to eq([])
      end
    end

    context "with HTML content in body" do
      it "strips HTML for diffing" do
        html_req = create(:requirement, project: project, section: section, created_by: user,
          title: "Test", body: "<p>Original <strong>bold</strong> text</p>")
        html_item = create(:review_item, review: review, requirement: html_req)
        html_item.snapshot_requirement!
        html_req.update!(body: "<p>Updated <em>italic</em> text</p>")

        diff = described_class.new(html_item.reload)
        body_field = diff.compute.find { |f| f.field == "body" }
        expect(body_field.diff_html).not_to include("<p>")
        expect(body_field.diff_html).not_to include("<strong>")
      end
    end

    context "with multiple changes" do
      before do
        requirement.update!(title: "New title", status: :in_review, priority: :should_have)
      end

      it "detects all changed fields" do
        changed = subject.changed_fields
        changed_names = changed.map(&:field)
        expect(changed_names).to include("title", "status", "priority")
      end
    end
  end

  describe "#any_changes?" do
    context "when nothing changed" do
      it "returns false" do
        expect(subject.any_changes?).to be false
      end
    end

    context "when something changed" do
      before { requirement.update!(title: "Changed") }

      it "returns true" do
        expect(subject.any_changes?).to be true
      end
    end
  end

  describe "#changed_fields" do
    before { requirement.update!(title: "Changed", body: "Changed body") }

    it "returns only changed fields" do
      changed = subject.changed_fields
      expect(changed.all?(&:changed)).to be true
      expect(changed.map(&:field)).to include("title", "body")
      expect(changed.map(&:field)).not_to include("uid")
    end
  end

  describe "field labels" do
    it "provides human-readable labels" do
      fields = subject.compute
      labels = fields.map(&:label)
      expect(labels).to include("UID", "Title", "Description", "Type", "Status",
                                "Priority", "ASIL Level", "Module", "Section")
    end
  end
end
