using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Exceptions
{
    public class InvalidCardSelectionException : SgsException
    {
        //public SelectedCardsSender Cards { get; protected set; }
        public TurnStages Stage { get; protected set; }
        public InvalidCardSelectionException(TurnStages stage) 
            : base(String.Format("The card(s) cannot be played during this stage {0}", stage.ToString()))
        {
            //this.Cards = cards;
            this.Stage = stage;
        }
    }
}
