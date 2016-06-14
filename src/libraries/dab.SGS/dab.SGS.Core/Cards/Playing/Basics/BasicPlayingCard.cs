using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Basics
{
    public abstract class BasicPlayingCard : PlayingCard
    {
        public BasicPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display, string details)
            : base(color, suite, display, details)
        {
        }
    }
}
