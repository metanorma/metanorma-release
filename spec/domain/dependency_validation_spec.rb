# frozen_string_literal: true

RSpec.describe Metanorma::Release::DependencyValidation do
  let(:validator_class) do
    mod = described_class
    Class.new do
      include mod

      attr_reader :component

      def initialize(component)
        @component = component
      end

      def validate!
        validate_interface!(component, Metanorma::Release::Publisher,
                            "component")
      end
    end
  end

  it "passes when component includes the interface module" do
    compliant = Class.new { include Metanorma::Release::Publisher }
    validator = validator_class.new(compliant.new)
    expect { validator.validate! }.not_to raise_error
  end

  it "raises ArgumentError when component does not include module" do
    non_compliant = Class.new
    validator = validator_class.new(non_compliant.new)
    expect do
      validator.validate!
    end.to raise_error(ArgumentError, /component must include/)
  end
end
