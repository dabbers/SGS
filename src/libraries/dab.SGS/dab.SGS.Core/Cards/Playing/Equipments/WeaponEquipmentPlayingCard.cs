using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Equipments
{
    public class WeaponEquipmentPlayingCard : EquipmentPlayingCard
    {
        public int Range { get { return this.range; } }
        

        public WeaponEquipmentPlayingCard(int range, PlayingCardColor color, PlayingCardSuite suite, string display,
            string details)
            : base(color, suite, display, details)
        {
        }

        public override bool Play()
        {
            if (this.Owner.PlayerArea.Weapon != null)
            {
                //this.Owner.PlayerArea.Weapon.RemoveAction(sender);
            }

            this.Context.Deck.DiscardPile.Add(this.Owner.PlayerArea.Weapon);
            this.Owner.PlayerArea.Weapon = this;
            this.Owner.Hand.Remove(this);

            return true;
        }

        public override bool IsPlayable()
        {
            return this.Context.CurrentTurnStage == TurnStages.Play;
        }

        public void AttackOccured()
        {
            //if (this.Actions == null) return;

            //foreach (var action in this.Actions)
            //{
            //    action.Perform(this, this.Owner, this.Context, result); // Why does this return bool? What do I use this for?
            //}

            //return;
        }

        public bool RemoveAction()
        {
            return true;
        }

        private int range = 1;
    }
}
