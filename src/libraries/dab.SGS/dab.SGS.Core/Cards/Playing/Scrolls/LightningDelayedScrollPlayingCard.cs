using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Scrolls
{
    public class LightningDelayedScrollPlayingCard : DelayedScrollPlayingCard
    {
        public LightningDelayedScrollPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string details) : base(color, suite, "Lightning", details)
        {
        }
    }
}
