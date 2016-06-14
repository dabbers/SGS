using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Exceptions
{
    public class InvalidCardException : SgsException
    {
        public Cards.Playing.PlayingCard Card { get; private set; }

        public InvalidCardException(Cards.Playing.PlayingCard card)
            : base(String.Format("{0} is an invalid selection", card))
        {
            this.Card = card;
        }
    }

}
