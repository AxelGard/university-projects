#include <string>
#include <vector>
#include <iostream>

using namespace std;

class Participant
{
public:
  Participant() = default;
  virtual ~Participant() = default;
  virtual bool defeats(Participant const* other) const = 0;
  virtual string get_name() const = 0;

  // remove copy constructor and copy assignment operator
  Participant(Participant const&) = delete;
  Participant& operator=(Participant const&) = delete;
};

class Named : public Participant
{
protected:
  string const name;

public:

  Named(string const& name)
    : name{name}
    { }
  
  string get_name() const override
  {
    return name;
  }
  

};

class Child : public Named
{
public:
  using Named::Named;
  bool defeats(Participant const* other) const override;
};

class Naughty_Child : public Child
{
public:
  using Child::Child;
  bool defeats(Participant const* other) const override;
};

class Reindeer : public Named
{
public:
  Reindeer(string name, bool glowing)
    : Named{name}, glowing{glowing}
  {
  }
  
  bool defeats(Participant const* other) const override;

  bool is_glowing() const
  {
    return glowing;
  }
  
private:
  bool glowing;
};

class Santa : public Participant
{
public:
  using Participant::Participant;

  bool defeats(Participant const* other) const override;

  string get_name() const override
  {
    return "Santa";
  }
};

bool Child::defeats(Participant const* other) const
{
  if (auto reindeer = dynamic_cast<Reindeer const*>(other))
  {
    if (reindeer->is_glowing())
    {
      return true;
    }
  }
  return false;
}

bool Naughty_Child::defeats(Participant const* other) const
{
  return Child::defeats(other) || typeid(*other) == typeid(Child);
}

bool Reindeer::defeats(Participant const* other) const
{
  return dynamic_cast<Santa const*>(other);
}

bool Santa::defeats(Participant const* other) const
{
  return dynamic_cast<Naughty_Child const*>(other);
}

/*
Correct output should be:
  
Wednesday Addams hits Kevin McCallister with a snowball!
Wednesday Addams hits Rudolf with a snowball!
Kevin McCallister hits Rudolf with a snowball!
Rudolf hits Santa with a snowball!
Cupid hits Santa with a snowball!
Santa hits Wednesday Addams with a snowball!  
 */
int main()
{
  vector<Participant*> participants {
    new Naughty_Child{"Wednesday Addams"},
    new Child{"Kevin McCallister"},
    new Reindeer{"Rudolf", true},
    new Reindeer{"Cupid", false},
    new Santa{}
  };

  for (auto p1 : participants)
  {
    for (auto p2 : participants)
    {
      if (p1 != p2)
      {
        if (p1->defeats(p2))
        {
          cout << p1->get_name() << " hits " << p2->get_name() << " with a snowball!" << endl;
        }
      }
    }
  }

  for (Participant* p : participants)
  {
    delete p;
  }
}