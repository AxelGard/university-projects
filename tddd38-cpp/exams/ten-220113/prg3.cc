#include <tuple>
#include <vector>
#include <string>
#include <cassert>
#include <map>
#include <stdexcept>

using namespace std;

template<typename T, typename Y, typename U>
class database {
    int last_id{};
    using row_type = tuple<T, Y, U>;
    map<int, row_type> rows{};

    public:
        int insert(T t, Y y, U u)
        {
            int id = last_id;
            rows[id] = {t,y,u};
            last_id++;
            return id;
        }

        row_type& get(int idx) {
            auto it = rows.find(idx);
            if (it == rows.end()){
                throw out_of_range("index: " + to_string(idx) + "  is out side of database range");
            }
            return rows[idx];
        }

        void remove(int idx){
            if (idx < 0 || idx > rows.size()) return;
            rows.erase(idx);
        }

        template<typename F> 
        vector<int> filter(F &&f)
        {
            vector<int> result{};
            for (auto &&[id, row] : rows)
            {
                if (f(id, std::forward<row_type>(row))){
                    result.push_back(id);
                }
            }
            return result;
        }
};

int main()
{
    // create a database
    database<int, std::string, int> db{};

    {
        // test that insertion works
        // and gives the correct id
        int id{db.insert(0, "a", 1)};
        assert(id == 0);

        // test that all the data can
        // be retrieved
        auto &&row{db.get(id)};
        assert(std::get<0>(row) == 0);
        assert(std::get<1>(row) == "a");
        assert(std::get<2>(row) == 1);
    }

    {
        // Test that lvalues also work
        int x{2};
        int id{db.insert(x, "b", x + 1)};
        assert(id == 1);

        auto &&row{db.get(id)};
        assert(std::get<0>(row) == 2);
        assert(std::get<1>(row) == "b");
        assert(std::get<2>(row) == 3);
    }

    {
        int id{db.insert(4, "c", 5)};
        assert(id == 2);

        auto &&row{db.get(id)};
        assert(std::get<0>(row) == 4);
        assert(std::get<1>(row) == "c");
        assert(std::get<2>(row) == 5);
    }

    // Test that remove can be called
    db.remove(1);

    // Make sure that trying to retrieve
    // a removed value throws an exception
    try
    {
        db.get(1);
        assert(false);
    }
    catch (...)
    {
    }

    // Test that retrieving non-existing columns
    // throws an exception.
    try
    {
        db.get(100);
        assert(false);
    }
    catch (...)
    {
    }

    // Make sure that the inserted value
    // work after removal, and that they
    // return the expected id.
    {
        int id{db.insert(6, "d", 7)};
        assert(id == 3);

        auto &&row{db.get(id)};
        assert(std::get<0>(row) == 6);
        assert(std::get<1>(row) == "d");
        assert(std::get<2>(row) == 7);
    }

    // Remove the last id.
    db.remove(3);

    // Make sure that the id counter still increases (doesn't reuse
    // ids)
    {
        int id{db.insert(8, "e", 9)};
        assert(id == 4);

        auto &&row{db.get(id)};
        assert(std::get<0>(row) == 8);
        assert(std::get<1>(row) == "e");
        assert(std::get<2>(row) == 9);
    }
    
    // Test the filter function
    {
        std::vector<int> result{
            db.filter([](int, auto &&data)
                      { return std::get<0>(data) % 4 == 0; })};
        assert((result == std::vector<int>{0, 2, 4}));
    }

    {
        std::vector<int> result{
            db.filter([](int id, auto &&)
                      { return id % 2 == 1; })};
        assert((result == std::vector<int>{}));
    }
}