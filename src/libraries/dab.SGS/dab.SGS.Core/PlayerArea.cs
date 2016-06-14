using dab.SGS.Core.Cards.Playing.Equipments;
using dab.SGS.Core.Cards.Playing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core
{

    public class PlayArea
    {
        public ShieldEquipmentPlayingCard Shield { get; set; }
        public WeaponEquipmentPlayingCard Weapon { get; set; }

        public HorseEquipmentPlayingCard PlusHorse { get; set; }

        public HorseEquipmentPlayingCard MinusHorse { get; set; }

        public List<PlayingCard> DelayedScrolls { get; set; }

        public List<PlayingCard> FaceUpPlayingCards { get; set; }

        public List<PlayingCard> FaceDownPlayingCards { get; set; }

        public void DiscardArea()
        {
            if (this.DelayedScrolls != null)
                foreach (var card in this.DelayedScrolls) card.Discard();
            if (this.FaceDownPlayingCards != null)
                foreach (var card in this.FaceDownPlayingCards) card.Discard();
            if (this.FaceUpPlayingCards != null)
                foreach (var card in this.FaceUpPlayingCards) card.Discard();

            this.Shield?.Discard();
            this.Weapon?.Discard();
            this.PlusHorse?.Discard();
            this.MinusHorse?.Discard();

        }

        public int NumberOfCards
        {
            get
            {
                return (this.Shield != null ? 1 : 0) + (this.Weapon != null ? 1 : 0) + (this.PlusHorse != null ? 1 : 0) +
                    (this.MinusHorse != null ? 1 : 0) + (this.DelayedScrolls?.Count ?? 0) + (this.FaceUpPlayingCards?.Count ?? 0) +
                    (this.FaceDownPlayingCards?.Count ?? 0);
            }
        }
    }
}
