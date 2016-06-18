using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Controllers;

namespace dab.SGS.Core.Cards.Playing.Basics
{
    public class WineBasicPlayingCard : BasicPlayingCard
    {
        public WineBasicPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string details) 
            : base(color, suite, "Wine", details)
        {
        }
    }
}
