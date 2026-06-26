# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/docker/file_updater"

# Multi-stage builds can pull files from an external image via
# `COPY --from=<image>:<tag>`. Updating that image should rewrite the
# `COPY --from` line while leaving named build stages untouched.
RSpec.describe Dependabot::Docker::FileUpdater do
  subject(:updated_dockerfile) do
    described_class.new(
      dependency_files: [dockerfile],
      dependencies: [dependency],
      credentials: credentials
    ).updated_dependency_files.find { |f| f.name == "Dockerfile" }
  end

  let(:dockerfile) do
    Dependabot::DependencyFile.new(
      name: "Dockerfile",
      content: fixture("docker", "dockerfiles", "copy_from")
    )
  end
  let(:credentials) do
    [{
      "type" => "git_source",
      "host" => "github.com",
      "username" => "x-access-token",
      "password" => "token"
    }]
  end
  let(:dependency) do
    Dependabot::Dependency.new(
      name: "nginx",
      version: "1.16.1",
      previous_version: "1.14.2",
      requirements: [{
        requirement: nil,
        groups: [],
        file: "Dockerfile",
        source: { tag: "1.16.1" }
      }],
      previous_requirements: [{
        requirement: nil,
        groups: [],
        file: "Dockerfile",
        source: { tag: "1.14.2" }
      }],
      package_manager: "docker"
    )
  end

  it "updates the image referenced by COPY --from" do
    expect(updated_dockerfile.content).to include "COPY --from=nginx:1.16.1 /etc/nginx"
  end

  it "leaves named build stages and unrelated images untouched" do
    expect(updated_dockerfile.content).to include "COPY --from=build /application/"
    expect(updated_dockerfile.content).to include "FROM node:10.9.2-alpine\n"
  end
end
