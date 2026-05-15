# frozen_string_literal: true

module Metanorma
  module Release
    module DocumentType
      STANDARD    = 'standard'
      IETF_DRAFT  = 'ietf-draft'
      IETF_RFC    = 'ietf-rfc'
      ISO         = 'iso'
      IEC         = 'iec'
      IEEE        = 'ieee'
      ITU         = 'itu'
      BIPM        = 'bipm'
      IHO         = 'iho'
      OGC         = 'ogc'
      OIML        = 'oiml'
      UN          = 'un'
      CSA         = 'csa'
      PDFA        = 'pdfa'
      MPFA        = 'mpfa'
      M3AAWG      = 'm3aawg'
      RIBOSE      = 'ribose'

      DETECTION_RULES = [
        [/^RFC\s/i,                              IETF_RFC],
        [/^draft-/i,                             IETF_DRAFT],
        [/^ISO/i,                                ISO],
        [/^IEC/i,                                IEC],
        [/^IEEE/i,                               IEEE],
        [/^ITU-/i,                               ITU],
        [/^BIPM/i,                               BIPM],
        [/^[A-Z]-\d/i,                           IHO],
        [/^\d{2}-\d{2,3}/,                       OGC],
        [/^OIML/i,                               OIML],
        [/^GE\./i,                               UN],
        [/^csa-/i,                               CSA],
        [/^(AN|BPG|TN)\s/i,                      PDFA],
        [%r{^SU/}i, MPFA],
        [/^M3AAWG/i,                             M3AAWG],
        [/^Ribose/i,                             RIBOSE]
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
