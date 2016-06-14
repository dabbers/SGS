using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Equipments
{
    public class ShieldEquipmentPlayingCard : EquipmentPlayingCard
    {
        
        public ShieldEquipmentPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display,
            string details) : base(color, suite, display, details)
        {
        }
        public override bool Play()
        {
            if (this.Owner.PlayerArea.Shield != null)
            {
                //this.Owner.PlayerArea.Shield.RemoveAction(sender);
            }

            this.Context.Deck.Discard(this.Owner.PlayerArea.Shield);
            this.Owner.PlayerArea.Shield = this;
            this.Owner.Hand.Remove(this);

            return true;
        }

        public override bool IsPlayable()
        {
            return this.Context.CurrentTurnStage == TurnStages.Play;
        }

        public bool CanBeAttacked()
        {
            return true;
        }

        /// <summary>
        /// Gets the extra damage an attack would cause with this weapon and this shield.
        /// </summary>
        /// <param name="result"></param>
        /// <param name="weapon"></param>
        /// <returns></returns>
        public int GetExtraDamage()
        {
            int damage = 0;
            
            return damage;
        }

        public bool RemoveAction()
        {
            return true;
        }
        
    }
}
