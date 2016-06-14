using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Controllers;

namespace dab.SGS.Core
{
    public class TurnStageDictionary : Dictionary<TurnStages, Controller>
    {
        public TurnStageDictionary()
        {
        }

        public TurnStageDictionary(int capacity) : base(capacity)
        {
        }

        public TurnStageDictionary(IEqualityComparer<TurnStages> comparer) : base(comparer)
        {
        }

        public TurnStageDictionary(IDictionary<TurnStages, Controller> dictionary) : base(dictionary)
        {
        }

        public TurnStageDictionary(int capacity, IEqualityComparer<TurnStages> comparer) : base(capacity, comparer)
        {
        }

        public TurnStageDictionary(IDictionary<TurnStages, Controller> dictionary, IEqualityComparer<TurnStages> comparer) : base(dictionary, comparer)
        {
        }

        public void Add(TurnStages stage, Controller action, bool chain = true)
        {
            //if (this.ContainsKey(stage))
            //{
            //    if (chain)
            //    {
            //        if (this[stage].GetType() != typeof(ChainedActions))
            //        {
            //            this[stage] = new ChainedActions("Chained Actions for " + stage.ToString(), new List<Actions.Action>() { this[stage] });
            //        }

            //        ((ChainedActions)this[stage]).Actions.Add(action);
            //    }
            //}
            //else
            //{
            //    if (chain)
            //    {
            //        base.Add(stage, new ChainedActions("Chained Actions for " + stage.ToString(), new List<Actions.Action>() { action }));
            //    }
            //    else
            //    {
            //        base.Add(stage, action);
            //    }
            //}
        }
    }
}
