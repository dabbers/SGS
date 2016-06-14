using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Exceptions
{
    public class InvalidStageException : SgsException
    {
        public TurnStages Stage { get; private set; }

        public InvalidStageException(TurnStages stage) 
            :base(String.Format("Invalid stage {0}", stage))
        {
            this.Stage = stage;
        }
    }
}
