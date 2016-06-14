using dab.SGS.Core.Cards.Playing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core
{

    public class GenericHoldingArea
    {
        public enum HoldingAreaVisibility
        {
            All,
            Player
        }

        public HoldingAreaVisibility Visibilty { get; set; }

        public List<PlayingCard> Cards { get; set; }
    }
}
