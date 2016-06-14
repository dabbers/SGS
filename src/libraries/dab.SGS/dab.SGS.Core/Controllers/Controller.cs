using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Cards.Playing.Equipments;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Controllers
{
    public abstract class Controller
    {
        public string Display { get { return this.display; } }

        public Controller(string display)
        {
            this.display = display;
        }

        public abstract bool Perform(GameContext context);

        //public static Controller ActionFromJson(dynamic obj)
        //{
        //    string cardType = obj.Type.ToString();
        //    var type = Type.GetType(String.Format("dab.SGS.Core.Actions.{0}", cardType));
        //    var fnc = type.GetMethod("ActionFromJson");

        //    // If no static ActionFromJson method is created, we can use the "defaul" constructor.
        //    if (fnc == null)
        //    {
        //        return (Controller)Activator.CreateInstance(type);
        //    }
        //    else
        //    {
        //        return (Controller)fnc.Invoke(null, new object[] { obj });
        //    }
        //}

        //internal static List<Controller> ActionsFromJson(dynamic actions)
        //{
        //    if (actions == null) return null;

        //    var lst = new List<Controller>();

        //    foreach(var action in actions)
        //    {
        //        lst.Add(Controller.ActionFromJson(action));
        //    }

        //    return lst;
        //}

        private string display = String.Empty;
    }
}
