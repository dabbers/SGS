using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Heroes
{
    public enum PlayableVerdict
    {
        Playable,
        NotPlayable,
        Unknown
    }

    public enum Kingdoms
    {
        Wei,
        Shu,
        Wu,
        Hero
    }



    
    public abstract class HeroCard
    {
        public string Display { get; private set; }
        public string Details { get; private set; }

        public int MaxHealth { get; private set; }


        public abstract PlayableVerdict IsCardPlayable(GameContext ctx, Playing.PlayingCard card);
    }
}
