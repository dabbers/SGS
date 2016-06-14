using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Exceptions
{
    public class InvalidScenarioException : SgsException
    {
        public InvalidScenarioException(string msg):base(msg)
        {

        }
    }
}
