require 'spec_helper'

describe AwesomeSpawn do
  subject { described_class }

  let(:params) do
    {
      "--user"  => "bob",
      "--pass"  => "P@$sw0^& |<>/-+*d%",
      "--db"    => nil,
      "--desc=" => "Some Description",
      nil       => ["pkg1", "some pkg"]
    }
  end

  let (:modified_params) do
    params.to_a + [123, 456].collect {|pool| ["--pool", pool]}
  end

  shared_examples_for "run" do
    context "paramater and command handling" do
      before do
        subject.stub(:exitstatus => 0)
      end

      it "sanitizes crazy params" do
        subject.should_receive(:launch).once.with("true --user bob --pass P@\\$sw0\\^\\&\\ \\|\\<\\>/-\\+\\*d\\% --db --desc=Some\\ Description pkg1 some\\ pkg --pool 123 --pool 456", {})
        subject.send(run_method, "true", :params => modified_params)
      end

      it "sanitizes fixnum array params" do
        subject.should_receive(:launch).once.with("true 1", {})
        subject.send(run_method, "true", :params => {nil => [1]})
      end

      it "sanitizes Pathname option value" do
        require 'pathname'
        subject.should_receive(:launch).once.with("true /usr/bin/ruby", {})
        subject.send(run_method, "true", :params => {nil => [Pathname.new("/usr/bin/ruby")]})
      end

      it "sanitizes Pathname option" do
        require 'pathname'
        subject.should_receive(:launch).once.with("true /usr/bin/ruby", {})
        subject.send(run_method, "true", :params => {Pathname.new("/usr/bin/ruby") => nil})
      end

      it "as empty hash" do
        subject.should_receive(:launch).once.with("true", {})
        subject.send(run_method, "true", :params => {})
      end

      it "as nil" do
        subject.should_receive(:launch).once.with("true", {})
        subject.send(run_method, "true", :params => nil)
      end

      it "won't modify caller params" do
        orig_params = params.dup
        subject.stub(:launch)
        subject.send(run_method, "true", :params => params)
        expect(orig_params).to eq(params)
      end

      it "Pathname command" do
        subject.should_receive(:launch).once.with("/usr/bin/ruby", {})
        subject.send(run_method, Pathname.new("/usr/bin/ruby"), {})
      end

      it "Pathname command with params" do
        subject.should_receive(:launch).once.with("/usr/bin/ruby -v", {})
        subject.send(run_method, Pathname.new("/usr/bin/ruby"), :params => {"-v" => nil})
      end

      it "supports spawn's chdir option" do
        subject.should_receive(:launch).once.with("true", {:chdir => ".."})
        subject.send(run_method, "true", :chdir => "..")
      end
    end

    context "with real execution" do
      before do
        # Re-enable actual spawning just for these specs.
        Kernel.stub(:spawn).and_call_original
      end

      it "command ok exit ok" do
        expect(subject.send(run_method, "true")).to be_kind_of AwesomeSpawn::CommandResult
      end

      it "command ok exit bad" do
        if run_method == "run!"
          error = nil

          # raise_error with do/end block notation is broken in rspec-expectations 2.14.x
          # and has been fixed in master but not yet released.
          # See: https://github.com/rspec/rspec-expectations/commit/b0df827f4c12870aa4df2f20a817a8b01721a6af
          expect {subject.send(run_method, "false")}.to raise_error {|e| error = e }
          expect(error).to be_kind_of AwesomeSpawn::CommandResultError
          expect(error.result).to be_kind_of AwesomeSpawn::CommandResult
        else
          expect {subject.send(run_method, "false")}.to_not raise_error
        end
      end

      it "command bad" do
        expect {subject.send(run_method, "XXXXX --user=bob")}.to raise_error(Errno::ENOENT, "No such file or directory - XXXXX")
      end

      context "#exit_status" do
        it "command ok exit ok" do
          expect(subject.send(run_method, "true").exit_status).to eq(0)
        end

        it "command ok exit bad" do
          expect(subject.send(run_method, "false").exit_status).to eq(1) if run_method == "run"
        end
      end

      context "#output" do
        it "command ok exit ok" do
          expect(subject.send(run_method, "echo \"Hello World\"").output).to eq("Hello World\n")
        end

        it "command ok exit bad" do
          expect(subject.send(run_method, "echo 'bad' && false").output).to eq("bad\n") if run_method == "run"
        end
      end

      context "#error" do
        it "command ok exit ok" do
          expect(subject.send(run_method, "echo \"Hello World\" >&2").error).to eq("Hello World\n")
        end

        it "command ok exit bad" do
          expect(subject.send(run_method, "echo 'bad' >&2 && false").error).to eq("bad\n") if run_method == "run"
        end
      end
    end
  end

  context ".run" do
    include_examples "run" do
      let(:run_method) {"run"}
    end
  end

  context ".run!" do
    include_examples "run" do
      let(:run_method) {"run!"}
    end
  end
end