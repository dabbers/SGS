using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Equipments
{
    public static class Shield
    {
        public const int NoEffect = -1000;
    }

    public abstract class ShieldEquipmentPlayingCard : EquipmentPlayingCard
    {
        
        public ShieldEquipmentPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display,
            string details) : base(color, suite, display, details)
        {
        }
        
        /// <summary>
        /// Gets the extra damage an attack would cause with this weapon and this shield.
        /// </summary>
        /// <param name="result"></param>
        /// <param name="weapon"></param>
        /// <returns>Number of extra damage caused. Returns Equipments.Shield.NoEffect (-1000) if cannot be attacked</returns>
        public abstract int GetExtraDamage();

        /// <summary>
        /// The action to perform when this shield is removed from the player area
        /// </summary>
        /// <returns></returns>
        public abstract void RemoveAction();
        
    }
}
