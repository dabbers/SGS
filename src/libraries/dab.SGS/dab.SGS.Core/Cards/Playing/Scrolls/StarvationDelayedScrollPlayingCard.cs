using dab.SGS.Core.Controllers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Scrolls
{
    public class StarvationDelayedScrollPlayingCard : DelayedScrollPlayingCard
    {
        public StarvationDelayedScrollPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string details) : base(color, suite, "Starvation", details)
        {
        }
    }
}
