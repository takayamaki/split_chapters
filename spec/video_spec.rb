# frozen_string_literal: true

require_relative '../video'

RSpec.describe Video do
  describe '#frame_rate' do
    def video_with(r_frame_rate:, avg_frame_rate:)
      described_class.new('/mnt/d/video.mkv', [], r_frame_rate: r_frame_rate, avg_frame_rate: avg_frame_rate)
    end

    context 'r_frame_rate と avg_frame_rate が一致する CFR 素材' do
      it 'r_frame_rate をそのまま返す' do
        expect(video_with(r_frame_rate: '30000/1001', avg_frame_rate: '30000/1001').frame_rate).to eq '30000/1001'
      end
    end

    context 'r_frame_rate と avg_frame_rate のズレが 1% 以内の素材' do
      it 'CFR とみなして r_frame_rate を返す'
    end

    context 'avg_frame_rate が r_frame_rate から 1% 超ズレる VFR 素材' do
      it 'avg が 45fps 以下なら 30 に正規化する'
      it 'avg が 45fps を超えるなら 60 に正規化する'
    end

    context 'avg_frame_rate が取れない (0/0) 素材' do
      it '30 に正規化する'
    end
  end
end
