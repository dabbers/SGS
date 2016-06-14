using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing.Scrolls
{
    public class ContentmentDelayedScrollPlayingCard : DelayedScrollPlayingCard
    {
        public ContentmentDelayedScrollPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string details) 
            : base(color, suite, "Contentment", details)
        {
        }

        public override bool IsPlayable()
        {
            return this.Context.CurrentTurnStage == TurnStages.Play;
        }
    }
}
