using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing
{
    /// <summary>
    /// Used for client side unknown cards. 
    /// DevNote: Should this be only in client instead? Do we need all those constructors
    /// </summary>
    public class OpponentPlayingCard : PlayingCard
    {
        public OpponentPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display, string details) : base(color, suite, display, details)
        {
        }

        protected OpponentPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display, string details, int id) : base(color, suite, display, details, id)
        {
        }
    }
}
