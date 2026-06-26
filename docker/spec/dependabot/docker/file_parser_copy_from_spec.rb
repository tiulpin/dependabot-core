# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency_file"
require "dependabot/source"
require "dependabot/docker/file_parser"

# Multi-stage builds can pull files from an external image via
# `COPY --from=<image>:<tag>`. These should be parsed as dependencies, while
# references to named build stages (e.g. `COPY --from=builder`) are ignored.
RSpec.describe Dependabot::Docker::FileParser do
  subject(:dependencies) do
    described_class.new(dependency_files: [dockerfile], source: source).parse
  end

  let(:dockerfile) do
    Dependabot::DependencyFile.new(
      name: "Dockerfile",
      content: fixture("docker", "dockerfiles", "copy_from")
    )
  end
  let(:source) do
    Dependabot::Source.new(provider: "github", repo: "gocardless/bump", directory: "/")
  end

  it "parses both the FROM image and the COPY --from image" do
    expect(dependencies.map(&:name)).to contain_exactly("node", "nginx")
  end

  it "ignores references to named build stages" do
    expect(dependencies.map(&:name)).not_to include("build")
  end

  describe "the COPY --from dependency" do
    subject(:dependency) { dependencies.find { |d| d.name == "nginx" } }

    it "has the right details" do
      expect(dependency.version).to eq("1.14.2")
      expect(dependency.requirements).to eq(
        [{
          requirement: nil,
          groups: [],
          file: "Dockerfile",
          source: { tag: "1.14.2" }
        }]
      )
    end
  end
end
