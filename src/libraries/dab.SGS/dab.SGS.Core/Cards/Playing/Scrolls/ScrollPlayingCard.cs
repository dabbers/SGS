using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Scrolls
{
    public abstract class ScrollPlayingCard : PlayingCard
    {

        public ScrollPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display, string details) : base(color, suite, display, details)
        {
        }
    }
}
