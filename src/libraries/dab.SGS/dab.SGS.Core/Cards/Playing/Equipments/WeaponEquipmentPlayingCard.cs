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
