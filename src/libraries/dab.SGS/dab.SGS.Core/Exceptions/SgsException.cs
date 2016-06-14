using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Exceptions
{
    public abstract class SgsException : Exception
    {
        public SgsException()
        {
        }

        public SgsException(string message) : base(message)
        {
        }

        public SgsException(string message, Exception innerException) : base(message, innerException)
        {
        }
    }
}
