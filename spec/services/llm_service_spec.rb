require "rails_helper"

RSpec.describe LlmService do
  subject(:service) { described_class.new }

  describe "#initialize" do
    it "uses default timeout of 30 seconds" do
      expect(service.timeout).to eq(30)
    end

    it "accepts custom timeout" do
      service = described_class.new(timeout: 60)
      expect(service.timeout).to eq(60)
    end
  end

  describe "#call" do
    let(:prompt) { "Analyze this requirement for quality" }

    context "when CLI returns valid JSON" do
      let(:json_response) { '{"score": 85, "issues": ["vague term: adequate"]}' }

      before do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return([json_response, "", status])
      end

      it "returns parsed JSON" do
        result = service.call(prompt)
        expect(result).to eq({ "score" => 85, "issues" => ["vague term: adequate"] })
      end

      it "passes the prompt to claude CLI" do
        service.call(prompt)
        expect(Open3).to have_received(:capture3).with(
          hash_including("PATH" => anything),
          "claude", "-p", prompt,
          hash_including(timeout: 30)
        )
      end
    end

    context "when CLI returns plain text" do
      before do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return(["This is a plain text response", "", status])
      end

      it "returns response wrapped in a hash with text key" do
        result = service.call(prompt)
        expect(result).to eq({ "text" => "This is a plain text response" })
      end
    end

    context "when requesting JSON format" do
      let(:json_response) { '{"analysis": "good"}' }

      before do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return([json_response, "", status])
      end

      it "includes --output-format json flag" do
        service.call(prompt, format: :json)
        expect(Open3).to have_received(:capture3).with(
          hash_including("PATH" => anything),
          "claude", "-p", prompt, "--output-format", "json",
          hash_including(timeout: 30)
        )
      end
    end

    context "when CLI exits with non-zero status" do
      before do
        status = instance_double(Process::Status, success?: false, exitstatus: 1)
        allow(Open3).to receive(:capture3).and_return(["", "Error: model not available", status])
      end

      it "raises LlmService::Error with stderr message" do
        expect { service.call(prompt) }.to raise_error(
          LlmService::Error, /CLI exited with status 1: Error: model not available/
        )
      end
    end

    context "when CLI exits with non-zero status and no stderr" do
      before do
        status = instance_double(Process::Status, success?: false, exitstatus: 2)
        allow(Open3).to receive(:capture3).and_return(["some output", "", status])
      end

      it "raises LlmService::Error with generic message" do
        expect { service.call(prompt) }.to raise_error(
          LlmService::Error, /CLI exited with status 2/
        )
      end
    end

    context "when CLI times out" do
      before do
        allow(Open3).to receive(:capture3).and_raise(Timeout::Error.new("execution expired"))
      end

      it "raises LlmService::TimeoutError" do
        expect { service.call(prompt) }.to raise_error(
          LlmService::TimeoutError, /timed out after 30 seconds/
        )
      end
    end

    context "when CLI command is not found" do
      before do
        allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT.new("claude"))
      end

      it "raises LlmService::Error with helpful message" do
        expect { service.call(prompt) }.to raise_error(
          LlmService::Error, /claude CLI not found/
        )
      end
    end

    context "when response contains JSON embedded in text" do
      let(:response) { "Here is the analysis:\n{\"score\": 90}\nDone." }

      before do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return([response, "", status])
      end

      it "extracts and parses the JSON object" do
        result = service.call(prompt)
        expect(result).to eq({ "score" => 90 })
      end
    end

    context "when response contains JSON array embedded in text" do
      let(:response) { "Results:\n[{\"id\": 1}, {\"id\": 2}]\nEnd." }

      before do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return([response, "", status])
      end

      it "extracts and parses the JSON array" do
        result = service.call(prompt)
        expect(result).to eq([{ "id" => 1 }, { "id" => 2 }])
      end
    end

    context "with custom timeout" do
      let(:service) { described_class.new(timeout: 120) }

      before do
        allow(Open3).to receive(:capture3).and_raise(Timeout::Error.new("execution expired"))
      end

      it "uses the custom timeout value in error message" do
        expect { service.call(prompt) }.to raise_error(
          LlmService::TimeoutError, /timed out after 120 seconds/
        )
      end

      it "passes custom timeout to capture3" do
        service.call(prompt) rescue nil
        expect(Open3).to have_received(:capture3).with(
          anything, "claude", "-p", prompt,
          hash_including(timeout: 120)
        )
      end
    end

    context "when response is empty" do
      before do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return(["", "", status])
      end

      it "returns hash with empty text" do
        result = service.call(prompt)
        expect(result).to eq({ "text" => "" })
      end
    end

    context "when response has whitespace-only content" do
      before do
        status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3).and_return(["  \n  \n  ", "", status])
      end

      it "returns hash with trimmed text" do
        result = service.call(prompt)
        expect(result).to eq({ "text" => "" })
      end
    end
  end

  describe "#call with system prompt" do
    before do
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return(['{"ok": true}', "", status])
    end

    it "passes system prompt via --system-prompt flag" do
      service.call("analyze this", system_prompt: "You are a requirements analyst")
      expect(Open3).to have_received(:capture3).with(
        anything,
        "claude", "-p", "analyze this",
        "--system-prompt", "You are a requirements analyst",
        hash_including(timeout: 30)
      )
    end
  end
end
