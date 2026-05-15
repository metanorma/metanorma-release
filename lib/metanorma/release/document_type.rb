# frozen_string_literal: true

module Metanorma
  module Release
    module DocumentType
      STANDARD    = "standard"
      IETF_DRAFT  = "ietf-draft"
      IETF_RFC    = "ietf-rfc"
      ISO         = "iso"
      IEC         = "iec"
      IEEE        = "ieee"
      ITU         = "itu"
      BIPM        = "bipm"
      IHO         = "iho"
      OGC         = "ogc"
      OIML        = "oiml"
      UN          = "un"
      CSA         = "csa"
      PDFA        = "pdfa"
      MPFA        = "mpfa"
      M3AAWG      = "m3aawg"
      RIBOSE      = "ribose"

      DETECTION_RULES = [
        [%r{^RFC\s}i,                              IETF_RFC],
        [%r{^draft-}i,                             IETF_DRAFT],
        [%r{^ISO}i,                                ISO],
        [%r{^IEC}i,                                IEC],
        [%r{^IEEE}i,                               IEEE],
        [%r{^ITU-}i,                               ITU],
        [%r{^BIPM}i,                               BIPM],
        [%r{^[A-Z]-\d}i,                           IHO],
        [%r{^\d{2}-\d{2,3}},                       OGC],
        [%r{^OIML}i,                               OIML],
        [%r{^GE\.}i,                               UN],
        [%r{^csa-}i,                               CSA],
        [%r{^(AN|BPG|TN)\s}i,                      PDFA],
        [%r{^SU/}i,                                MPFA],
        [%r{^M3AAWG}i,                             M3AAWG],
        [%r{^Ribose}i,                             RIBOSE]
      ].freeze

      def self.from_identifier(raw_id)
        id = raw_id.to_s.strip
        return STANDARD if id.empty?

        DETECTION_RULES.each do |pattern, type|
          return type if id.match?(pattern)
        end

        STANDARD
      end
    end
  end
end
