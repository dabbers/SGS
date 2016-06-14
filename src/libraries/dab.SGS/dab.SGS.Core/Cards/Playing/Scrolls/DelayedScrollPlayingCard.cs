using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Scrolls
{
    public abstract class DelayedScrollPlayingCard : ScrollPlayingCard
    {
        public DelayedScrollPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display, string details) : base(color, suite, display, details)
        {
        }


        public override bool PlayJudgement(PlayingCard card)
        {
            return true;
        }
        
    }
}
