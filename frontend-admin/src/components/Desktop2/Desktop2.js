import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import './Desktop2.css';
import form from "../../assets/form.png";
import Directory from "../../assets/Directory.png";
import menu from "../../assets/menu.png";
import profile from "../../assets/profile.png";
import search from "../../assets/search.png";

function Desktop2() {
  const [forms, setForms] = useState([]);

  // Fetch form data on component mount
  useEffect(() => {
    const fetchForms = async () => {
      try {
        const response = await axios.get('http://localhost:5000/forms');
        console.log('Fetched forms:', response.data); // Log the response
        setForms(response.data);
      } catch (error) {
        console.error('Error fetching forms:', error);
      }
    };

    fetchForms();
  }, []);

  return (
    <div className="desktop2-container">
      <aside className="desktop2-sidebar">
        <div className="desktop2-sidebar-item">
          <Link to="/desktop2">
            <img src={Directory} alt="Directory" />
            <span>Directory</span>
          </Link>
        </div>
        <div className="desktop2-sidebar-item">
          <Link to="/desktop1">
            <img src={form} alt="Forms" />
            <span>Form</span>
          </Link>
        </div>
      </aside>

      <div className="desktop2-main-content">
        <header className="desktop2-topbar">
          <img src={menu} alt="Menu" className="desktop2-hamburger-icon" />
          <div className="desktop2-search-bar">
            <img src={search} alt="Search" className="desktop2-search-icon" />
            <input type="text" placeholder="Search" />
            <button className="desktop2-add-button">+</button>
          </div>
          <div className="desktop2-profile-icon">
            <img src={profile} alt="Profile" />
          </div>
        </header>

        <div className="desktop2-content">
          <h2 className="desktop2-header">Directory</h2>
          <div className="desktop2-search">
            <input type="text" placeholder="Search" />
            <img className='search' src={search} alt="Search" />
          </div>

          <div className="desktop2-directory">
            {forms.length > 0 ? (
              forms.map((form) => (
                <div className="desktop2-card" key={form._id}>
                  <h3>{form.name}</h3>
                  <p>Occupation: {form.occupation}</p>
                  <p>Phone: {form.phoneNumber}</p>
                  {/* Add more fields as necessary */}
                </div>
              ))
            ) : (
              <p>No forms available</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default Desktop2;
